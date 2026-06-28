import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../board/hex.dart';
import '../../effects/particles.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';
import '../projectile/projectile.dart';
import 'tower_component.dart';

final _rnd = Random();

/// 依塔種建立對應的元件。
TowerComponent buildTower(TowerType type, BoardPoint location) {
  switch (type) {
    case TowerType.freezing:
      return FreezingTowerComponent(location);
    case TowerType.flame:
      return FlameTowerComponent(location);
    case TowerType.airBlade:
      return AirBladeTowerComponent(location);
    case TowerType.thunder:
      return ThunderTowerComponent(location);
    case TowerType.obstacle:
      return ObstacleTowerComponent(location);
  }
}

/// 冰凍塔：場上只要有敵人就放出以自身為中心、會擴張的減速冰環。
class FreezingTowerComponent extends TowerComponent {
  FreezingTowerComponent(BoardPoint location)
      : super(TowerType.freezing, location);

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;
    final enemy = game.enemies.where((e) => !e.isDead).firstOrNull;
    if (enemy != null) attemptShoot(enemy);
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return FreezeProjectileComponent(
      damage: damage,
      start: logicalPos.clone(),
      toRadius: game.board.hexagonRadius * range,
      duration: 2000,
    );
  }
}

/// 火焰塔：以最小角度差鎖定敵人，慢慢轉向並持續噴出火焰子彈。
class FlameTowerComponent extends TowerComponent {
  FlameTowerComponent(BoardPoint location) : super(TowerType.flame, location);

  static const double rotateSpeed = 0.08;

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());

    final t = target;
    if (t != null) {
      if (!t.isDead && t.isMounted) {
        final diff = t.logicalPos - logicalPos;
        if (game.isInsideRange(diff, range)) {
          final targetAngle = atan2(diff.y, diff.x);
          final delta = targetAngle - direction;
          final amount = min(rotateSpeed, delta.abs());
          direction += delta.sign * amount;
          attemptShoot(t);
          return;
        }
      }
      target = null;
    }

    EnemyComponent? best;
    var bestDiff = double.infinity;
    for (final e in game.enemiesInRange(logicalPos, range)) {
      final a = atan2(e.logicalPos.y - logicalPos.y, e.logicalPos.x - logicalPos.x);
      final d = (a - direction).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = e;
      }
    }
    target = best;
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    final fix = (Random().nextDouble() * 0.4) - 0.2;
    return FlameProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 0.5,
      travelAngle: direction + fix,
      lengthHex: range / 2,
    );
  }
}

/// 風刃塔：持續旋轉，對前方扇形範圍內的敵人造成傷害（無子彈）。
class AirBladeTowerComponent extends TowerComponent {
  AirBladeTowerComponent(BoardPoint location)
      : super(TowerType.airBlade, location);

  static const double spinSpeed = 0.2;
  static const double arc = 25 * pi / 180;

  double _windEmit = 0;

  @override
  void update(double dt) {
    direction += spinSpeed;

    final targets = game.enemiesInRange(logicalPos, range).where((e) {
      final diff = e.logicalPos - logicalPos;
      final a = atan2(diff.y, diff.x);
      return _between(direction, direction + arc, a);
    }).toList();

    for (final e in targets) {
      e.dealDamage(damage);
    }

    // 刃尖噴出風的粒子。
    _windEmit += dt * 1000;
    if (_windEmit >= 140) {
      _windEmit = 0;
      final tip = logicalPos +
          Vector2(cos(direction), sin(direction)) *
              (game.board.hexagonRadius * range * 0.55);
      game.world.add(windBurst(game.logicalToScreen(tip), game.iso.scaleX,
          count: 3));
    }
  }

  bool _between(double start, double end, double target) {
    double n(double r) => r % (2 * pi);
    start = n(start);
    end = n(end);
    target = n(target);
    if (start > end) return target >= start || target <= end;
    return target >= start && target <= end;
  }

  @override
  void render(Canvas canvas) {
    // 半透明貼地旋轉風刃。用 isometric 地面基底向量做仿射變換，直接在「邏輯
    // 地面」上畫圓弧，投影後角度就會跟地磚一致；用正常混色(非 additive)、
    // 前緣淡綠(非純白)以保留透明感。
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final foot = Offset(size.x / 2, size.y / 2);
    final rL = game.board.hexagonRadius * 1.35; // 邏輯半徑
    final rect = Rect.fromCircle(center: Offset.zero, radius: rL);

    canvas
      ..save()
      ..translate(foot.dx, foot.dy)
      ..transform(Float64List.fromList([
        ax.x, ax.y, 0, 0, //
        ay.x, ay.y, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]));

    // 地面風環
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = Colors.greenAccent.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rL * 0.45,
    );

    // 主刃 + 拖尾（往後逐漸變淡、變窄）
    const trail = 8;
    for (var k = 0; k < trail; k++) {
      final f = 1 - k / trail;
      canvas.drawArc(
        rect,
        direction - k * 0.12,
        0.34,
        false,
        Paint()
          ..color = (k == 0 ? Colors.lightGreenAccent : Colors.greenAccent)
              .withOpacity(0.30 * f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = rL * (0.12 + 0.4 * f)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    super.render(canvas);
  }
}

/// 雷電塔：沿用基底鎖定 / 開火，發射會在敵群之間連鎖的雷電子彈。
class ThunderTowerComponent extends TowerComponent {
  ThunderTowerComponent(BoardPoint location)
      : super(TowerType.thunder, location);

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return ThunderProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1,
      target: enemy,
      chainLimit: 4,
      chainDistance: 5,
    );
  }
}

/// 障礙物：純粹擋路，不攻擊。每次隨機挑一種石堆樣式，讓每顆都有點不同。
class ObstacleTowerComponent extends TowerComponent {
  ObstacleTowerComponent(BoardPoint location)
      : super(TowerType.obstacle, location);

  late final Sprite _variant =
      game.obstacleSprites[_rnd.nextInt(game.obstacleSprites.length)];

  @override
  Sprite get sprite => _variant;

  @override
  void update(double dt) {}
}

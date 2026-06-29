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
    case TowerType.cannon:
      return CannonTowerComponent(location);
    case TowerType.poison:
      return PoisonTowerComponent(location);
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
    direction = (direction + spinSpeed) % (2 * pi);

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

  static const double slashSpan = 0.95; // 斬擊新月的角度跨度(rad)

  @override
  void render(Canvas canvas) {
    // 斬擊刀光：尖端收尖、中間飽滿的新月刀光(貼地)，外緣有一道亮刀刃，
    // 後方兩道較淡殘影做出揮砍的動態模糊。
    final foot = Offset(size.x / 2, size.y / 2);
    final rOut = game.board.hexagonRadius * 1.4; // 邏輯半徑
    _slash(canvas, foot, rOut, direction - 0.34, fill: 0.06, edge: 0.0);
    _slash(canvas, foot, rOut, direction - 0.17, fill: 0.13, edge: 0.25);
    _slash(canvas, foot, rOut, direction, fill: 0.26, edge: 0.8);
    super.render(canvas);
  }

  /// 在地面平面畫一道新月刀光：前緣(旋轉前端)最亮，沿弧線往後越來越淡。
  void _slash(
    Canvas canvas,
    Offset foot,
    double rOut,
    double a0, {
    required double fill,
    required double edge,
  }) {
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final thickness = rOut * 0.5;
    const seg = 18;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var i = 0; i <= seg; i++) {
      final t = slashSpan * i / seg; // 固定 0~slashSpan，旋轉交給 canvas.rotate
      final taper = sin(pi * i / seg); // 兩端 0、中間 1 → 收尖
      final rin = rOut - thickness * taper;
      outer.add(Offset(cos(t) * rOut, sin(t) * rOut));
      inner.add(Offset(cos(t) * rin, sin(t) * rin));
    }
    final crescent = Path()..moveTo(outer.first.dx, outer.first.dy);
    for (var i = 1; i < outer.length; i++) {
      crescent.lineTo(outer[i].dx, outer[i].dy);
    }
    for (var i = inner.length - 1; i >= 0; i--) {
      crescent.lineTo(inner[i].dx, inner[i].dy);
    }
    crescent.close();

    final rect = Rect.fromCircle(center: Offset.zero, radius: rOut);
    // 沿弧線的漸層：a0(後端)透明 → a0+slashSpan(前端)亮。
    Shader sweep(Color c, double a, List<double> stops, List<double> ops) {
      return SweepGradient(
        startAngle: 0,
        endAngle: slashSpan,
        colors: [for (final o in ops) c.withOpacity(o * a)],
        stops: stops,
      ).createShader(rect);
    }

    canvas
      ..save()
      ..translate(foot.dx, foot.dy)
      ..transform(Float64List.fromList([
        ax.x, ax.y, 0, 0, //
        ay.x, ay.y, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]))
      ..rotate(a0); // 旋轉由此處理，刀光幾何/漸層永遠用固定角度
    if (fill > 0) {
      canvas.drawPath(
        crescent,
        Paint()..shader = sweep(Colors.green.shade700, fill, [0, 1], [0, 1]),
      );
    }
    if (edge > 0) {
      final blade = Path()..moveTo(outer.first.dx, outer.first.dy);
      for (var i = 1; i < outer.length; i++) {
        blade.lineTo(outer[i].dx, outer[i].dy);
      }
      canvas.drawPath(
        blade,
        Paint()
          // 亮光集中在前端 ~40%，往後快速淡掉。
          ..shader = sweep(Colors.green, edge, [0, 0.6, 1], [0, 0, 1])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
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

/// 火炮塔：鎖定最近敵人，發射砲彈在落點爆炸造成範圍傷害。
class CannonTowerComponent extends TowerComponent {
  CannonTowerComponent(BoardPoint location) : super(TowerType.cannon, location);

  static const double blastHex = 1.4; // 爆炸半徑（格）

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return CannonProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1.2,
      targetPos: enemy.logicalPos.clone(),
      blastHex: blastHex,
    );
  }
}

/// 毒塔：鎖定最近敵人，射出毒液使其中毒持續扣血。
class PoisonTowerComponent extends TowerComponent {
  PoisonTowerComponent(BoardPoint location) : super(TowerType.poison, location);

  static const int poisonDuration = 3000; // 中毒持續時間(ms)

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return PoisonProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1.4,
      target: enemy,
      duration: poisonDuration,
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

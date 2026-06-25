import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../board/hex.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';
import '../projectile/projectile.dart';
import 'tower_component.dart';

/// 依塔種建立對應的元件。取代舊版 PlayerProvider.placeBuilding 的 switch。
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
      start: position.clone(),
      toRadius: game.board.hexagonRadius * range,
      duration: 2000,
    );
  }

  @override
  void renderTurret(Canvas canvas) {
    drawIcon(canvas, Icons.ac_unit, size: 24, color: Colors.white);
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
        final diff = t.position - position;
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

    // 重新鎖定：選與目前砲口角度差最小的敵人。
    EnemyComponent? best;
    var bestDiff = double.infinity;
    for (final e in game.enemiesInRange(position, range)) {
      final a = atan2(e.position.y - position.y, e.position.x - position.x);
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

  @override
  void renderTurret(Canvas canvas) {
    drawTurret(canvas, w: 25, h: 12, color: Colors.redAccent);
  }
}

/// 風刃塔：持續旋轉，對前方扇形範圍內的敵人造成傷害（無子彈）。
class AirBladeTowerComponent extends TowerComponent {
  AirBladeTowerComponent(BoardPoint location)
      : super(TowerType.airBlade, location);

  static const double spinSpeed = 0.2;
  static const double arc = 25 * pi / 180;

  @override
  void update(double dt) {
    direction += spinSpeed;

    final targets = game.enemiesInRange(position, range).where((e) {
      final diff = e.position - position;
      final a = atan2(diff.y, diff.x);
      return _between(direction, direction + arc, a);
    }).toList();

    for (final e in targets) {
      e.dealDamage(damage);
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
  void renderTurret(Canvas canvas) {
    drawTurret(canvas, w: 90, h: 5, color: Colors.blueGrey);
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

  @override
  void renderTurret(Canvas canvas) {
    drawTurret(canvas, w: 25, h: 10, color: Colors.amberAccent);
  }
}

/// 障礙物：純粹擋路，不攻擊。
class ObstacleTowerComponent extends TowerComponent {
  ObstacleTowerComponent(BoardPoint location)
      : super(TowerType.obstacle, location);

  @override
  void update(double dt) {}

  @override
  void render(Canvas canvas) {
    drawHexBase(canvas, Colors.black87);
    final r = game.board.hexagonRadius * 0.7 * 0.9;
    canvas.drawPath(hexPath(r), Paint()..color = Colors.brown);
  }
}

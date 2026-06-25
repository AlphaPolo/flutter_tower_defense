import 'dart:collection';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
import '../../effects/effect.dart';
import '../../tower_defense_game.dart';
import '../enemy_component.dart';

/// 子彈 / 投射物的共同基底。各子型別在 [onTick] 內自行決定移動與傷害。
abstract class ProjectileComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  ProjectileComponent({
    required this.damage,
    required Vector2 start,
    required this.speed,
  }) : super(priority: 30) {
    position = start;
  }

  double damage;
  double speed;
  Vector2? goal;
  double lifeTime = 0;
  double clock = 0;
  bool dead = false;

  int flyingTime(Vector2 from, Vector2 to, double speed) =>
      ((from - to).length / (speed / 3)).floor();

  @override
  void update(double dt) {
    onTick(dt * 1000);
    if (dead) removeFromParent();
  }

  void onTick(double dtMs);
}

/// 普通子彈：朝目標飛行的灰色小點（與舊版一致，本身不造成傷害）。
class NormalProjectileComponent extends ProjectileComponent {
  NormalProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.target,
  });

  final EnemyComponent target;
  late Vector2 _start;

  @override
  void onMount() {
    super.onMount();
    if (!target.isMounted) {
      dead = true;
      return;
    }
    _start = position.clone();
    goal = target.position.clone();
    lifeTime = flyingTime(_start, goal!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (lifeTime <= 0 || clock >= lifeTime) {
      dead = true;
      return;
    }
    final t = (clock / lifeTime).clamp(0.0, 1.0);
    position = _start + (goal! - _start) * t;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 5, Paint()..color = Colors.grey);
  }
}

/// 火焰塔子彈：朝固定方向噴出一段距離，沿途持續對 40px 內的敵人造成傷害。
class FlameProjectileComponent extends ProjectileComponent {
  FlameProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.travelAngle,
    required this.lengthHex,
  });

  final double travelAngle;
  final double lengthHex;
  late Vector2 _start;

  @override
  void onMount() {
    super.onMount();
    _start = position.clone();
    final dist = game.board.hexagonRadius * lengthHex;
    goal = _start + Vector2(cos(travelAngle), sin(travelAngle)) * dist;
    lifeTime = flyingTime(_start, goal!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (lifeTime <= 0 || clock >= lifeTime) {
      dead = true;
      return;
    }
    final t = (clock / lifeTime).clamp(0.0, 1.0);
    position = _start + (goal! - _start) * t;

    for (final e in game.enemies) {
      if (e.isDead) continue;
      if (e.position.distanceTo(position) <= 40) {
        e.dealDamage(damage);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final t = lifeTime <= 0 ? 0.0 : (clock / lifeTime).clamp(0.0, 1.0);
    final r = 5 + 5 * t; // 5 → 10
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.redAccent);
  }
}

/// 冰凍塔子彈：以塔為中心擴張的冰環，把進入範圍的敵人減速。
class FreezeProjectileComponent extends ProjectileComponent {
  FreezeProjectileComponent({
    required super.damage,
    required super.start,
    required this.toRadius,
    this.fromRadius = 0,
    this.duration = 1000,
  }) : super(speed: 1);

  final double toRadius;
  final double fromRadius;
  final int duration;
  double currentRadius = 0;
  final Set<EnemyComponent> effected = {};

  @override
  void onMount() {
    super.onMount();
    lifeTime = duration.toDouble();
    currentRadius = fromRadius;
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (clock >= lifeTime) {
      dead = true;
      return;
    }
    final t = (clock / lifeTime).clamp(0.0, 1.0);
    currentRadius = fromRadius + (toRadius - fromRadius) * t;

    for (final e in game.enemies) {
      if (e.isDead || effected.contains(e)) continue;
      if (e.position.distanceTo(position) < currentRadius) {
        effected.add(e);
        e.addEffect(
          SlowMovementEffect(kFrozenEffectType, 800, StatCalcType.multi, 0.3),
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    const center = Offset(0, -4);
    final rect = Rect.fromCircle(center: center, radius: currentRadius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.blue.withOpacity(0.5)],
        stops: const [0.5, 1],
      ).createShader(rect);
    canvas.drawCircle(center, currentRadius, paint);
  }
}

/// 雷電塔子彈：先飛向目標，抵達後沿敵群連鎖造成傷害並麻痺。
class ThunderProjectileComponent extends ProjectileComponent {
  ThunderProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.target,
    required this.chainLimit,
    this.chainDistance = 2,
  });

  EnemyComponent target;
  final int chainLimit;
  double chainDistance;
  List<Vector2>? bindEnemies;
  late Vector2 _start;

  bool get isChainState => bindEnemies != null && bindEnemies!.isNotEmpty;

  @override
  void onMount() {
    super.onMount();
    _start = position.clone();
    if (!target.isMounted) {
      dead = true;
      return;
    }
    goal = target.position.clone();
    lifeTime = flyingTime(_start, goal!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;

    if (isChainState) {
      if (clock >= lifeTime) dead = true;
      return;
    }

    if (clock < lifeTime) {
      final t = lifeTime <= 0 ? 1.0 : (clock / lifeTime).clamp(0.0, 1.0);
      position = _start + (goal! - _start) * t;
      return;
    }

    // 抵達目標，開始連鎖。
    position = (target.isMounted && !target.isDead)
        ? target.position.clone()
        : goal!;

    final chained = _chainEnemies(target);
    final list = <Vector2>[];
    for (final e in chained) {
      e.addEffect(SlowMovementEffect.flat(kThunderEffectType, 800, 0.0, 300));
      e.dealDamage(damage);
      list.add(e.position - position);
    }

    if (list.isEmpty) {
      dead = true;
      return;
    }

    bindEnemies = list;
    lifeTime = 1000;
    clock = 0;
  }

  Set<EnemyComponent> _chainEnemies(EnemyComponent from) {
    final frontier = Queue<EnemyComponent>()..add(from);
    final visited = <EnemyComponent>{};

    final candidates = game.enemies.where((e) => !e.isDead).toList()
      ..sort(
        (a, b) => (a.position - position)
            .length
            .compareTo((b.position - position).length),
      );

    bool inRange(EnemyComponent a, EnemyComponent b) =>
        game.isInsideRange(a.position - b.position, chainDistance);

    while (frontier.isNotEmpty) {
      final next = <EnemyComponent>[];
      for (final e in frontier) {
        for (final cand in candidates.where((c) => inRange(c, e))) {
          if (visited.length >= chainLimit) break;
          visited.add(cand);
          next.add(cand);
        }
        candidates.removeWhere(visited.contains);
      }
      frontier
        ..clear()
        ..addAll(next);
    }

    return visited;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (!isChainState) {
      canvas.drawCircle(Offset.zero, 5, Paint()..color = Colors.yellow);
      return;
    }

    canvas.drawCircle(Offset.zero, 8, paint);
    final nodes = bindEnemies!;
    for (var i = 0; i < nodes.length; i++) {
      if (clock < i * 20) continue;
      final off = Offset(nodes[i].x, nodes[i].y);
      final phase = ((clock / lifeTime) * 4) % 1.0;
      final r = (8 + (2 - 8) * phase).clamp(2.0, 8.0);
      canvas.drawLine(Offset.zero, off, paint);
      canvas.drawCircle(off, r, paint);
    }
  }
}

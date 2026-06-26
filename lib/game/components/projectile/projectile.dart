import 'dart:collection';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
import '../../effects/effect.dart';
import '../../effects/particles.dart';
import '../../tower_defense_game.dart';
import '../enemy_component.dart';

final _rnd = Random();

/// 子彈基底（isometric 版）。移動/傷害在 top-down 邏輯座標計算，每幀投影成
/// 螢幕座標繪製。飛行子彈畫在最上層；地面 AoE 由子型別調低 priority。
abstract class ProjectileComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  ProjectileComponent({
    required this.damage,
    required Vector2 start,
    required this.speed,
  }) {
    logical.setFrom(start);
  }

  double damage;
  double speed;

  final Vector2 logical = Vector2.zero();
  Vector2? goalLogical;
  double lifeTime = 0;
  double clock = 0;
  bool dead = false;

  /// 螢幕像素 / 邏輯單位（拿來縮放繪製尺寸）。
  double get s => game.iso.scaleX;

  int flyingTime(Vector2 from, Vector2 to, double speed) =>
      ((from - to).length / (speed / 3)).floor();

  @override
  void onMount() {
    super.onMount();
    priority = 2000000;
    _sync();
  }

  void _sync() => position.setFrom(game.logicalToScreen(logical));

  @override
  void update(double dt) {
    onTick(dt * 1000);
    _sync();
    if (dead) removeFromParent();
  }

  void onTick(double dtMs);

  void lerpLogical(Vector2 from, Vector2 to, double t) {
    logical
      ..setFrom(to)
      ..sub(from)
      ..scale(t)
      ..add(from);
  }
}

/// 普通子彈：發光的小灰點（不造成傷害，與舊版一致）。
class NormalProjectileComponent extends ProjectileComponent {
  NormalProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.target,
  });

  final EnemyComponent target;
  final Vector2 _start = Vector2.zero();

  @override
  void onMount() {
    super.onMount();
    if (!target.isMounted) {
      dead = true;
      return;
    }
    _start.setFrom(logical);
    goalLogical = target.logicalPos.clone();
    lifeTime = flyingTime(_start, goalLogical!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (lifeTime <= 0 || clock >= lifeTime) {
      dead = true;
      return;
    }
    lerpLogical(_start, goalLogical!, (clock / lifeTime).clamp(0.0, 1.0));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 6 * s,
        Paint()..color = Colors.white24..blendMode = BlendMode.plus);
    canvas.drawCircle(Offset.zero, 4 * s, Paint()..color = Colors.grey);
  }
}

/// 火焰塔子彈：邊飛邊噴火花，發光火球，沿途持續傷害 40(邏輯px) 內的敵人。
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
  final Vector2 _start = Vector2.zero();
  double _emit = 0;

  @override
  void onMount() {
    super.onMount();
    _start.setFrom(logical);
    final dist = game.board.hexagonRadius * lengthHex;
    goalLogical = _start + Vector2(cos(travelAngle), sin(travelAngle)) * dist;
    lifeTime = flyingTime(_start, goalLogical!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (lifeTime <= 0 || clock >= lifeTime) {
      dead = true;
      return;
    }
    lerpLogical(_start, goalLogical!, (clock / lifeTime).clamp(0.0, 1.0));
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if (e.logicalPos.distanceTo(logical) <= 40) e.dealDamage(damage);
    }
    _emit += dtMs;
    if (_emit >= 50) {
      _emit = 0;
      game.world.add(fireBurst(game.logicalToScreen(logical), s, count: 2));
    }
  }

  @override
  void render(Canvas canvas) {
    final t = lifeTime <= 0 ? 0.0 : (clock / lifeTime).clamp(0.0, 1.0);
    final base = (6 + 6 * t) * s;
    final flick = 0.85 + _rnd.nextDouble() * 0.3;
    void blob(double r, Color c) => canvas.drawCircle(
        Offset.zero, r, Paint()..color = c..blendMode = BlendMode.plus);
    blob(base * 1.4 * flick, Colors.red.withOpacity(0.22));
    blob(base * flick, Colors.deepOrange.withOpacity(0.5));
    blob(base * 0.6 * flick, Colors.orange.withOpacity(0.85));
    blob(base * 0.3 * flick, Colors.yellow);
  }
}

/// 冰凍塔子彈：以塔為中心擴張的減速冰環（貼地橢圓 + 霜環 + 雪花），施放時噴霜。
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
    priority = -1; // 貼地，畫在棋盤之上、單位之下
    lifeTime = duration.toDouble();
    currentRadius = fromRadius;
    game.world.add(frostBurst(game.logicalToScreen(logical), game.iso.scaleX));
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
      if (e.logicalPos.distanceTo(logical) < currentRadius) {
        effected.add(e);
        e.addEffect(
          SlowMovementEffect(kFrozenEffectType, 800, StatCalcType.multi, 0.3),
        );
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final rx = currentRadius * game.iso.scaleX;
    final ry = currentRadius * game.iso.scaleY;
    final fade = (1 - clock / lifeTime).clamp(0.0, 1.0);
    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.lightBlueAccent.withOpacity(0.35)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.lightBlueAccent.withOpacity(0.9 * fade),
    );
    const n = 10;
    final ph = clock / lifeTime;
    for (var i = 0; i < n; i++) {
      final a = 2 * pi * i / n + ph * 2;
      canvas.drawCircle(
        Offset(cos(a) * rx, sin(a) * ry),
        1.6 * game.iso.scaleX,
        Paint()..color = Colors.white.withOpacity(fade),
      );
    }
  }
}

/// 雷電塔子彈：飛向目標，抵達後沿敵群連鎖（鋸齒閃電 + 火花）造成傷害並麻痺。
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
  List<Vector2>? bindLogical;
  final Vector2 _start = Vector2.zero();

  bool get isChainState => bindLogical != null && bindLogical!.isNotEmpty;

  @override
  void onMount() {
    super.onMount();
    _start.setFrom(logical);
    if (!target.isMounted) {
      dead = true;
      return;
    }
    goalLogical = target.logicalPos.clone();
    lifeTime = flyingTime(_start, goalLogical!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;

    if (isChainState) {
      if (clock >= lifeTime) dead = true;
      return;
    }

    if (clock < lifeTime) {
      lerpLogical(_start, goalLogical!,
          lifeTime <= 0 ? 1.0 : (clock / lifeTime).clamp(0.0, 1.0));
      return;
    }

    logical.setFrom((target.isMounted && !target.isDead)
        ? target.logicalPos
        : goalLogical!);

    final chained = _chainEnemies(target);
    final list = <Vector2>[];
    for (final e in chained) {
      e.addEffect(SlowMovementEffect.flat(kThunderEffectType, 800, 0.0, 300));
      e.dealDamage(damage);
      list.add(e.logicalPos.clone());
      game.world.add(sparkBurst(game.logicalToScreen(e.logicalPos), s));
    }
    if (list.isEmpty) {
      dead = true;
      return;
    }
    bindLogical = list;
    lifeTime = 1000;
    clock = 0;
  }

  Set<EnemyComponent> _chainEnemies(EnemyComponent from) {
    final frontier = Queue<EnemyComponent>()..add(from);
    final visited = <EnemyComponent>{};

    final candidates = game.enemies.where((e) => !e.isDead).toList()
      ..sort((a, b) => (a.logicalPos - logical)
          .length
          .compareTo((b.logicalPos - logical).length));

    bool inRange(EnemyComponent a, EnemyComponent b) =>
        game.isInsideRange(a.logicalPos - b.logicalPos, chainDistance);

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

  void _bolt(Canvas canvas, Offset a, Offset b, Paint paint) {
    const segs = 6;
    final dir = b - a;
    final len = dir.distance == 0 ? 1.0 : dir.distance;
    final nx = -dir.dy / len, ny = dir.dx / len;
    final path = Path()..moveTo(a.dx, a.dy);
    for (var i = 1; i < segs; i++) {
      final t = i / segs;
      final mid = Offset.lerp(a, b, t)!;
      final j = (_rnd.nextDouble() * 2 - 1) * 8 * s;
      path.lineTo(mid.dx + nx * j, mid.dy + ny * j);
    }
    path.lineTo(b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  @override
  void render(Canvas canvas) {
    if (!isChainState) {
      canvas.drawCircle(Offset.zero, 8 * s,
          Paint()..color = Colors.yellow..blendMode = BlendMode.plus);
      canvas.drawCircle(Offset.zero, 4 * s, Paint()..color = Colors.white);
      return;
    }

    final glow = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..blendMode = BlendMode.plus;
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s;

    final center = game.logicalToScreen(logical);
    final nodes = bindLogical!;
    for (var i = 0; i < nodes.length; i++) {
      if (clock < i * 20) continue;
      final scr = game.logicalToScreen(nodes[i]) - center;
      final off = Offset(scr.x, scr.y);
      _bolt(canvas, Offset.zero, off, glow);
      _bolt(canvas, Offset.zero, off, core);
    }
  }
}

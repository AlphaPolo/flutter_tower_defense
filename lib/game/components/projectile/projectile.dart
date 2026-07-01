import 'dart:math';
import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
import '../../board/hex.dart';
import '../../effects/effect.dart';
import '../../effects/particles.dart';
import '../../tower_defense_game.dart';
import '../enemy_component.dart';
import 'chain_targets.dart';

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

/// 火炮塔砲彈：拋向目標落點，命中後爆炸，對落點 [blastHex] 半徑內所有敵人造成傷害。
class CannonProjectileComponent extends ProjectileComponent {
  CannonProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.targetPos,
    required this.blastHex,
  });

  final Vector2 targetPos;
  final double blastHex;
  final Vector2 _start = Vector2.zero();

  @override
  void onMount() {
    super.onMount();
    _start.setFrom(logical);
    goalLogical = targetPos.clone();
    lifeTime = flyingTime(_start, goalLogical!, speed).toDouble();
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (lifeTime <= 0 || clock >= lifeTime) {
      _explode();
      dead = true;
      return;
    }
    lerpLogical(_start, goalLogical!, (clock / lifeTime).clamp(0.0, 1.0));
  }

  void _explode() {
    final blast = game.board.hexagonRadius * blastHex;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if (e.logicalPos.distanceTo(goalLogical!) <= blast) e.dealDamage(damage);
    }
    game.world.add(
      explosionBurst(game.logicalToScreen(goalLogical!), game.iso.scaleX),
    );
  }

  @override
  void render(Canvas canvas) {
    // 拋物線：飛行中段往上抬，像砲彈飛行弧線。
    final t = lifeTime <= 0 ? 1.0 : (clock / lifeTime).clamp(0.0, 1.0);
    final lift = sin(t * pi) * 26 * s;
    canvas.drawCircle(
      Offset(0, -lift),
      5 * s,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      Offset(0, -lift),
      5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.orange.withOpacity(0.8),
    );
  }
}

/// 毒塔子彈：飛向目標，命中後讓敵人中毒（持續傷害）。
class PoisonProjectileComponent extends ProjectileComponent {
  PoisonProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.target,
    required this.duration,
  });

  final EnemyComponent target;
  final int duration;
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
      if (target.isMounted && !target.isDead) {
        // damage 視為「整段持續時間造成的總傷害」→ 換算每秒。
        final dps = damage / (duration / 1000.0);
        target.addEffect(PoisonEffect(kPoisonEffectType, duration, dps));
        game.world.add(poisonBurst(target.position.clone(), game.iso.scaleX));
      }
      dead = true;
      return;
    }
    if (target.isMounted) goalLogical = target.logicalPos.clone();
    lerpLogical(_start, goalLogical!, (clock / lifeTime).clamp(0.0, 1.0));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 5 * s, Paint()..color = Colors.green);
    canvas.drawCircle(
      Offset.zero,
      5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.lightGreenAccent,
    );
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
    // 灼燒按 dt 結算（damage 為每秒 DPS）→ 與 fps 無關。
    final burn = damage * dtMs / 1000;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      if (e.logicalPos.distanceTo(logical) <= 40) e.dealDamage(burn);
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
    // 用 isometric 地面基底做仿射，在邏輯地面畫圓 → 投影後貼合地磚角度。
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final r = currentRadius; // 邏輯半徑
    final fade = (1 - clock / lifeTime).clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);

    canvas
      ..save()
      ..transform(Float64List.fromList([
        ax.x, ax.y, 0, 0, //
        ay.x, ay.y, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1, //
      ]));
    // 柔邊填色
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.lightBlueAccent.withOpacity(0.35)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
    // 外環
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.lightBlueAccent.withOpacity(0.9 * fade),
    );
    // 環上雪花
    const n = 10;
    final ph = clock / lifeTime;
    for (var i = 0; i < n; i++) {
      final a = 2 * pi * i / n + ph * 2;
      canvas.drawCircle(
        Offset(cos(a) * r, sin(a) * r),
        1.0,
        Paint()..color = Colors.white.withOpacity(fade),
      );
    }
    canvas.restore();
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

    final chained = _chainEnemies();
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

  /// 從落點 [logical] 起，沿存活敵群連鎖（最近優先、上限 [chainLimit]、
  /// 每跳間距上限 [chainDistance] 格）。實際演算法見 [chainTargets]（純函式、有測試）。
  List<EnemyComponent> _chainEnemies() {
    final live = game.enemies.where((e) => !e.isDead).toList();
    final picked = chainTargets(
      origin: logical,
      positions: [for (final e in live) e.logicalPos],
      maxDistance: game.board.hexagonRadius * chainDistance,
      limit: chainLimit,
    );
    return [for (final i in picked) live[i]];
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

/// 滾木：沿固定方向等速滾動，壓過範圍內的每隻敵人各造成一次傷害（敵人不會擋下它）。
/// 撞到建築（towers；陷阱不在其中 → 不擋）或滾出棋盤即停止。
class RollingLogProjectileComponent extends ProjectileComponent {
  RollingLogProjectileComponent({
    required super.damage,
    required super.start,
    required super.speed,
    required this.travelAngle,
    required this.originCell,
    required this.dirIndex,
  });

  final double travelAngle;
  final BoardPoint originCell; // 塔自身格：起始不因它而停
  final int dirIndex; // spritesheet 的方向列（= HexagonDirection.index）
  final Vector2 _dir = Vector2.zero();
  final Set<EnemyComponent> _crushed = {};
  double _rolled = 0; // 已滾距離（給滾動條紋用）

  static const double _crushHex = 0.55; // 壓過半徑（格）

  @override
  void onMount() {
    super.onMount();
    _dir.setFrom(Vector2(cos(travelAngle), sin(travelAngle)));
  }

  @override
  void onTick(double dtMs) {
    final step = (speed / 3) * dtMs; // 沿用其他 projectile 的 speed 語意（px/ms）
    logical.x += _dir.x * step;
    logical.y += _dir.y * step;
    _rolled += step;

    // 與敵人/塔同層、依螢幕 y 深度排序（+1 讓滾木蓋在同層敵人之上）；
    // 這樣前方(較大 y)的塔會擋住滾木，不再蓋到塔頂。
    priority = game.logicalToScreen(logical).y.round() + 1;

    // 壓過範圍內、還沒壓到的敵人 → 各造成一次傷害。
    final r = game.board.hexagonRadius * _crushHex;
    for (final e in game.enemies) {
      if (e.isDead || _crushed.contains(e)) continue;
      if (e.logicalPos.distanceTo(logical) <= r) {
        e.dealDamage(damage);
        _crushed.add(e);
      }
    }

    // 停止：滾出棋盤，或撞到建築（塔/障礙；陷阱不在 towers → 不擋）。起始格(塔自身)不算。
    final bp = game.board.pointToBoardPoint(Offset(logical.x, logical.y));
    if (bp == null) {
      dead = true; // 滾出場外
      return;
    }
    if (bp != originCell && game.towers.containsKey(bp)) {
      dead = true; // 撞上建築停下
      return;
    }
  }

  static const double _framePx = 14; // 每滾動幾 px 換一幀

  @override
  void render(Canvas canvas) {
    final size = game.board.hexagonRadius * game.iso.scaleX * 1.8;

    // 貼地陰影：沿滾木長度方向（垂直於行進方向）的扁橢圓，貼合木頭形狀、淺色微模糊。
    final perp = Vector2(-_dir.y, _dir.x); // 長度軸（垂直行進）
    final lenScr =
        game.logicalToScreen(logical + perp) - game.logicalToScreen(logical);
    canvas.save();
    canvas.rotate(atan2(lenScr.y, lenScr.x));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 0.6,
        height: size * 0.13,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();

    final cell = TowerDefenseGame.logCell;
    final frame =
        (_rolled / _framePx).floor() % TowerDefenseGame.logFrameCount;
    final src = Rect.fromLTWH(frame * cell, dirIndex * cell, cell, cell);
    final dst = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    canvas.drawImageRect(
      game.logSheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

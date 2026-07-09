import 'dart:math';
import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
import '../../board/hex.dart';
import '../explosion_component.dart';
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

/// 砲彈速度曲線：出膛稍快 → 拋物線頂點最慢 → 落地加速砸下（單次、可調）。
/// 速度(斜率) = c + hang·(t-0.5)² + slam·(t-0.5)：兩端快、中段慢；[slam] 讓
/// 落地端比出膛端更快（砸下感）。[hang] 越大頂點越慢、兩端越快。
class _ShotCurve extends Curve {
  const _ShotCurve({this.hang = 3.0, this.slam = 1.5});
  final double hang;
  final double slam;

  @override
  double transformInternal(double t) {
    final c = 1 - hang / 12;
    final u = t - 0.5;
    return c * t + hang * u * u * u / 3 + slam * u * u / 2 + hang / 24 - slam / 8;
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
    this.centerPeak = 0,
  });

  final Vector2 targetPos;
  final double blastHex;
  // 中心加成峰值（0=關）：中心處傷害 = damage × (1 + centerPeak)，邊緣為 1×。
  // 例：1.0 → 最高 2×、1.5 → 最高 2.5×。
  final double centerPeak;
  final Vector2 _start = Vector2.zero();

  /// 固定飛行時間：不論遠近，射出到落地都一樣長（可預期、弧線一致）。
  static const double _flightMs = 420;

  /// 速度曲線（juice）：出膛稍快、拋物線頂點最慢、落地加速砸下。
  /// 水平與弧高共用同一條 → 頂點(弧最高處)也是最慢的地方。
  static const _shotCurve = _ShotCurve(hang: 3.0, slam: 1.5);
  double get _t {
    final raw = (clock / _flightMs).clamp(0.0, 1.0);
    return _shotCurve.transform(raw);
  }

  /// 出膛高度（螢幕 px）：約塔頂投石機的位置，讓砲彈從塔頂射出而非地面。
  double get _launchPx => game.board.hexagonRadius * s * 1.1;

  /// 目前砲彈相對地面的抬升（螢幕 px）：出膛高度漸收 + 拋物線弧。繪製與尾跡共用。
  double get _lift => _launchPx * (1 - _t) + sin(_t * pi) * 32 * s;

  double _smokeT = 0; // 硝煙尾跡計時（ms）

  @override
  void onMount() {
    super.onMount();
    _start.setFrom(logical);
    goalLogical = targetPos.clone();
    lifeTime = _flightMs;
  }

  @override
  void onTick(double dtMs) {
    clock += dtMs;
    if (clock >= lifeTime) {
      _explode();
      dead = true;
      return;
    }
    lerpLogical(_start, goalLogical!, _t);
    // 硝煙尾跡：沿飛行路徑（含抬升）定期生成一小團灰煙。
    _smokeT += dtMs;
    if (_smokeT >= 18) {
      _smokeT = 0;
      game.world
          .add(smokePuff(game.logicalToScreen(logical) + Vector2(0, -_lift), s));
    }
  }

  void _explode() {
    final blast = game.board.hexagonRadius * blastHex;
    for (final e in game.enemies) {
      if (e.isDead) continue;
      final d = e.logicalPos.distanceTo(goalLogical!);
      if (d <= blast) {
        // 基礎傷害(邊緣 1×)；中心加成峰值 centerPeak（0=關），越靠中心加越多（線性）。
        final mult = 1.0 + centerPeak * (1 - d / blast);
        e.dealDamage(damage * mult);
      }
    }
    final screenPos = game.logicalToScreen(goalLogical!);
    game.world.add(ExplosionComponent(
      screenPos: screenPos,
      diameter: blast * 2.6 * game.iso.scaleX,
      blastLogical: blast,
    ));

    // 螢幕震動：離觀測點（畫面中心）越近震得越明顯，稍微隨位置變動。
    final vf = game.camera.viewfinder;
    final visibleHalf = game.size.length / (2 * vf.zoom); // 視野半對角線(世界單位)
    final t = (screenPos.distanceTo(vf.position) / visibleHalf).clamp(0.0, 1.0);
    final falloff = 1.0 - 0.4 * t; // 中心 1.0、邊緣 0.6
    game.cameraShake.shake(7.0 * falloff);
  }

  @override
  void render(Canvas canvas) {
    // 拋物線：從塔頂投石機高度([_launchPx])出發，中段抬升成弧線，落到地面(0)。
    final lift = _lift;
    canvas.drawCircle(
      Offset(0, -lift),
      7 * s,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      Offset(0, -lift),
      7 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.orange.withValues(alpha: 0.85),
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
    this.pctPerSec = 0,
  });

  final EnemyComponent target;
  final int duration;
  final double pctPerSec; // 每秒額外扣「命中時最大血量」的百分比
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
        // damage 視為「整段持續時間造成的總傷害」→ 換算每秒；
        // 另加「每秒依命中時最大血量的百分比」扣血（升級提高 pctPerSec）。
        final dps = damage / (duration / 1000.0) +
            pctPerSec * target.status.totalHp;
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
    this.burnDps = 0,
  });

  final double travelAngle;
  final double lengthHex;
  final double burnDps; // >0：命中後留下持續燃燒（每秒 burnDps，離開火焰後仍延燒）
  static const int _burnMs = 3000; // 持續燃燒時間（每次命中刷新）
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
      if (e.logicalPos.distanceTo(logical) <= 40) {
        e.dealDamage(burn, physical: false, feedback: false); // 火焰＝持續元素傷害、不閃白
        // 熾流：命中即附加/刷新持續燃燒（離開火焰後仍延燒 _burnMs）。
        if (burnDps > 0) {
          e.addEffect(PoisonEffect(kBurnEffectType, _burnMs, burnDps));
        }
      }
    }
    _emit += dtMs;
    if (_emit >= 50) {
      _emit = 0;
      game.world.add(fireBurst(game.logicalToScreen(logical), s,
          count: 2, opacity: game.dimFlame.value ? 0.5 : 1.0));
    }
  }

  @override
  void render(Canvas canvas) {
    final t = lifeTime <= 0 ? 0.0 : (clock / lifeTime).clamp(0.0, 1.0);
    final base = (6 + 6 * t) * s;
    final flick = 0.85 + _rnd.nextDouble() * 0.3;
    final a = game.dimFlame.value ? 0.5 : 1.0; // 開關：變淡時整體透明度減半
    void blob(double r, Color c) => canvas.drawCircle(
        Offset.zero, r, Paint()..color = c..blendMode = BlendMode.plus);
    blob(base * 1.4 * flick, Colors.red.withValues(alpha: 0.22 * a));
    blob(base * flick, Colors.deepOrange.withValues(alpha: 0.5 * a));
    blob(base * 0.6 * flick, Colors.orange.withValues(alpha: 0.85 * a));
    blob(base * 0.3 * flick, Colors.yellow.withValues(alpha: a));
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
    this.slowFactor = 0.3,
    this.vulnAmp = 0,
  }) : super(speed: 1);

  final double toRadius;
  final double fromRadius;
  final int duration;
  final double slowFactor; // 減速倍率（越小＝越慢，0.3 = 剩 30% 速度）
  final double vulnAmp; // >0：冰環同時使敵人脆弱化（物理受傷 +vulnAmp）
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
          SlowMovementEffect(
              kFrozenEffectType, 800, StatCalcType.multi, slowFactor),
        );
        // 霜牢：冰環同時使敵人脆弱化（受物理攻擊多吃傷害），持續 5 秒、可刷新。
        if (vulnAmp > 0) {
          e.addEffect(VulnerableEffect(kVulnerableEffectType, 5000, vulnAmp));
        }
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
          colors: [Colors.transparent, Colors.lightBlueAccent.withValues(alpha: 0.35)],
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
        ..color = Colors.lightBlueAccent.withValues(alpha: 0.9 * fade),
    );
    // 環上雪花
    const n = 10;
    final ph = clock / lifeTime;
    for (var i = 0; i < n; i++) {
      final a = 2 * pi * i / n + ph * 2;
      canvas.drawCircle(
        Offset(cos(a) * r, sin(a) * r),
        1.0,
        Paint()..color = Colors.white.withValues(alpha: fade),
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
    this.paralyzeChance = 0,
    this.paralyzeMs = 0,
  });

  EnemyComponent target;
  final int chainLimit;
  double chainDistance;
  final double paralyzeChance;
  final int paralyzeMs;

  /// 連鎖確定後的「邊」快照（from→to 邏輯座標）——依實際 BFS 接力路徑繪製，
  /// 而不是全部畫回落點的星形（視覺要跟演算法一致）。
  List<(Vector2, Vector2)>? bindEdges;
  final Vector2 _start = Vector2.zero();

  bool get isChainState => bindEdges != null && bindEdges!.isNotEmpty;

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

    final live = game.enemies.where((e) => !e.isDead).toList();
    final edges = chainEdges(
      origin: logical,
      positions: [for (final e in live) e.logicalPos],
      maxDistance: game.board.hexagonRadius * chainDistance,
      limit: chainLimit,
    );
    final list = <(Vector2, Vector2)>[];
    for (final edge in edges) {
      final e = live[edge.index];
      // 命中必定麻痺（速度設為 0），時間依塔等級。
      if (_rnd.nextDouble() < paralyzeChance) {
        e.addEffect(
            SlowMovementEffect.flat(kThunderEffectType, paralyzeMs, 0.0, 300));
      }
      e.dealDamage(damage, physical: false); // 雷電＝元素傷害
      // 邊快照：from＝parent（-1＝落點，否則為中繼敵人當下位置）。
      final from = edge.parent == -1
          ? logical.clone()
          : live[edge.parent].logicalPos.clone();
      list.add((from, e.logicalPos.clone()));
      game.world.add(sparkBurst(game.logicalToScreen(e.logicalPos), s));
    }
    if (list.isEmpty) {
      dead = true;
      return;
    }
    bindEdges = list;
    lifeTime = 1000;
    clock = 0;
  }

  /// 從落點 [logical] 起，沿存活敵群連鎖（最近優先、上限 [chainLimit]、
  /// 每跳間距上限 [chainDistance] 格）。實際演算法見 [chainTargets]（純函式、有測試）。
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
      ..color = Colors.yellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..blendMode = BlendMode.plus;
    final core = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s;

    // 沿「連鎖邊」逐段繪製（BFS 順序 → 電流一段段竄出去的感覺），
    // 反映實際接力路徑，而不是全部連回落點。
    final center = game.logicalToScreen(logical);
    final edges = bindEdges!;
    for (var i = 0; i < edges.length; i++) {
      if (clock < i * 20) continue;
      final aScr = game.logicalToScreen(edges[i].$1) - center;
      final bScr = game.logicalToScreen(edges[i].$2) - center;
      final a = Offset(aScr.x, aScr.y);
      final b = Offset(bScr.x, bScr.y);
      _bolt(canvas, a, b, glow);
      _bolt(canvas, a, b, core);
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
  double _age = 0; // 存活時間(ms)，給拋出彈跳用

  static const double _crushHex = 0.55; // 壓過半徑（格）
  static const double _bounceMs = 520; // 拋出彈跳持續時間

  @override
  void onMount() {
    super.onMount();
    _dir.setFrom(Vector2(cos(travelAngle), sin(travelAngle)));
  }

  @override
  void onTick(double dtMs) {
    _age += dtMs;
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

    // 停止：滾出棋盤，或撞到建築（塔/障礙；陷阱不在 towers → 不擋），
    // 或撞到擋路型天然環境（巨石/密林/水池）。起始格(塔自身)不算。
    final bp = game.board.pointToBoardPoint(Offset(logical.x, logical.y));
    if (bp == null) {
      dead = true; // 滾出場外
      return;
    }
    if (bp != originCell && game.towers.containsKey(bp)) {
      dead = true; // 撞上建築停下
      return;
    }
    if (bp != originCell && (game.environment[bp]?.blocks ?? false)) {
      dead = true; // 撞上擋路型天然環境（巨石/密林/水池）停下
      return;
    }
  }

  static const double _framePx = 14; // 每滾動幾 px 換一幀

  /// 拋出彈跳：出場一小段時間，滾木在陰影上方彈跳（兩下、幅度遞減）。
  /// 回傳往上偏移的像素高度（0 = 已落地）。
  double _bounceHeight(double amp) {
    if (_age >= _bounceMs) return 0;
    final t = _age / _bounceMs; // 0..1
    return amp * (1 - t) * (sin(t * pi * 2)).abs(); // 兩個彈跳、幅度隨時間衰減
  }

  @override
  void render(Canvas canvas) {
    final size = game.board.hexagonRadius * game.iso.scaleX * 1.8;
    final amp = game.board.hexagonRadius * game.iso.scaleX * 0.5; // 彈跳最大高度
    final bounce = _bounceHeight(amp);
    final norm = amp <= 0 ? 0.0 : (bounce / amp).clamp(0.0, 1.0); // 0(貼地)~1(最高)

    // 貼地陰影：沿滾木長度方向的扁橢圓；騰空時縮小變淡（強化拋出感）。
    final perp = Vector2(-_dir.y, _dir.x);
    final lenScr =
        game.logicalToScreen(logical + perp) - game.logicalToScreen(logical);
    canvas.save();
    canvas.rotate(atan2(lenScr.y, lenScr.x));
    final shScale = 1 - norm * 0.4;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size * 0.6 * shScale,
        height: size * 0.13 * shScale,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14 * (1 - norm * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.restore();

    // 滾木本體：往上偏移 = 彈跳高度。
    final cell = TowerDefenseGame.logCell;
    final frame =
        (_rolled / _framePx).floor() % TowerDefenseGame.logFrameCount;
    final src = Rect.fromLTWH(frame * cell, dirIndex * cell, cell, cell);
    final dst = Rect.fromCenter(
      center: Offset(0, -bounce),
      width: size,
      height: size,
    );
    canvas.drawImageRect(
      game.logSheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// 狙擊塔弩箭：沿固定方向高速直飛的投射物（不追蹤）。傷害在「命中當下」
/// 逐敵結算：獵首（血量比例 ≥ [huntTh] → ×1.5）、重型加成（heavy ×(1+[heavyMul])）。
/// [pierce] false＝命中第一個敵人即消失；true＝貫穿沿途全部敵人直到彈道終點。
/// 彈道終點 [end] 由塔計算（已依「彈道破除」與否被天然地形截斷）。
class SniperBoltProjectileComponent extends ProjectileComponent {
  SniperBoltProjectileComponent({
    required super.damage, // 基礎傷害（含主動技倍率）；獵首/重型命中時再乘
    required Vector2 start,
    required super.speed,
    required Vector2 end,
    required this.huntTh,
    required this.heavyMul,
    required this.pierce,
    this.distRamp = 0,
  }) : super(start: start) {
    _start.setFrom(start);
    _end.setFrom(end);
  }

  final double huntTh;
  final double heavyMul;
  final bool pierce;
  final double distRamp; // 百步穿楊：每飛 1 格 +distRamp（上限 +100%）

  final Vector2 _start = Vector2.zero();
  final Vector2 _end = Vector2.zero();
  final Vector2 _u = Vector2.zero(); // 單位方向
  final Set<EnemyComponent> _hit = {};
  double _traveled = 0;
  double _totalLen = 0;

  @override
  void onMount() {
    super.onMount();
    _totalLen = _start.distanceTo(_end);
    if (_totalLen <= 0) {
      dead = true;
      return;
    }
    _u
      ..setFrom(_end)
      ..sub(_start)
      ..scale(1 / _totalLen);
  }

  /// 命中單發傷害：獵首與重型加成依「命中當下」該敵人的狀態各自計算；
  /// 百步穿楊依「飛到該敵人的距離」[hitDist]（邏輯 px）加成。
  double _damageFor(EnemyComponent e, double hitDist) {
    var dmg = damage;
    if (e.status.currentHp / e.status.totalHp >= huntTh) dmg *= 1.5;
    if (e.kind.heavy && heavyMul > 0) dmg *= 1 + heavyMul;
    if (distRamp > 0) {
      // 1 格 = 相鄰格心距 = √3 × hexagonRadius。加成封頂 +100%（×2）。
      final cells = hitDist / (game.board.hexagonRadius * sqrt(3));
      dmg *= 1 + min(distRamp * cells, 1.0);
    }
    return dmg;
  }

  @override
  void onTick(double dtMs) {
    final prev = _traveled;
    _traveled = min(_traveled + (speed / 3) * dtMs, _totalLen);
    logical
      ..setFrom(_u)
      ..scale(_traveled)
      ..add(_start);

    // 這一幀掃過的線段 [prev, _traveled]：距離線段 ≤ 半寬的敵人算命中
    //（用線段而非目前點 → 高速下不會跳過敵人）。半寬依體型放寬。
    for (final e in game.enemies) {
      if (e.isDead || !e.isMounted || _hit.contains(e)) continue;
      final rel = e.logicalPos - _start;
      final alongRaw = rel.x * _u.x + rel.y * _u.y; // 敵人在彈道上的投影距離
      final along = alongRaw.clamp(prev, _traveled);
      final px = _start.x + _u.x * along - e.logicalPos.x;
      final py = _start.y + _u.y * along - e.logicalPos.y;
      final halfW = game.board.hexagonRadius * (0.35 + 0.2 * e.kind.sizeMul);
      if (px * px + py * py > halfW * halfW) continue;
      _hit.add(e);
      // 距離加成用投影距離（幾何量，不吃幀率），不用命中當幀的 _traveled。
      e.dealDamage(_damageFor(e, alongRaw.clamp(0.0, _totalLen)));
      game.world.add(sparkBurst(
          game.logicalToScreen(e.logicalPos) - Vector2(0, 10 * s), s));
      if (!pierce) {
        dead = true;
        return;
      }
    }

    if (_traveled >= _totalLen) dead = true; // 抵達彈道終點（地形/場邊）
  }

  @override
  void render(Canvas canvas) {
    // 箭身沿「螢幕投影後」的飛行方向（吃 iso 壓扁），略抬離地面。
    final d = game.logicalToScreen(logical + _u) - game.logicalToScreen(logical);
    final len = d.length;
    if (len <= 0) return;
    final ux = d.x / len, uy = d.y / len;
    final lift = Offset(0, -10 * s);
    final tip = lift + Offset(ux, uy) * (9 * s);
    final tail = lift - Offset(ux, uy) * (15 * s);
    // 外圈暖色光暈（拖出速度感）+ 內芯亮白 + 箭頭。
    canvas.drawLine(
      tail - Offset(ux, uy) * (10 * s),
      tip,
      Paint()
        ..color = const Color(0xFFFFB74D).withValues(alpha: 0.45)
        ..strokeWidth = 3.5 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.8 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, 2.2 * s, Paint()..color = const Color(0xFFFFE082));
  }
}

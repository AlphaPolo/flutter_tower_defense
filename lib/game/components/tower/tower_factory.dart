import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
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
    case TowerType.log:
      return LogTowerComponent(location);
    case TowerType.multishot:
      return MultishotTowerComponent(location);
    case TowerType.obstacle:
      return ObstacleTowerComponent(location);
    case TowerType.spike:
    case TowerType.vortex:
      // 陷阱類不走塔工廠（由 buildTrap 建立）。
      throw ArgumentError('$type 為陷阱，請改用 buildTrap');
  }
}

/// 滾木塔：**方向由玩家控制**（點選塔時可左右旋轉），每隔一段時間朝該方向滾出巨木。
/// 木頭壓過沿途的敵人（各一次傷害、不被敵人擋下），直到撞上建築或滾出場外。
class LogTowerComponent extends TowerComponent {
  LogTowerComponent(BoardPoint location) : super(TowerType.log, location);

  // 依升級：傷害 / 發射間隔(ms)。
  @override
  double get damage => mod(TowerMod.dmg,40);
  @override
  int get fireCD => mod(TowerMod.cd,3000).toInt();

  /// 玩家可調整的發射方向（6 個六角方向之一）。
  late HexagonDirection launchDir;

  @override
  void onMount() {
    super.onMount();
    launchDir = _defaultDir(); // 預設朝主堡方向，玩家可再調整
  }

  HexagonDirection _defaultDir() {
    final aim = game.boardToLogical(game.targetLocation) - logicalPos;
    var best = HexagonDirection.values.first;
    var bestDot = -double.infinity;
    for (final d in HexagonDirection.values) {
      final n = game.boardToLogical(location.getNeighbor(d)) - logicalPos;
      final dot = n.x * aim.x + n.y * aim.y;
      if (dot > bestDot) {
        bestDot = dot;
        best = d;
      }
    }
    return best;
  }

  /// 發射方向的角度（邏輯座標）。
  double get _launchAngle {
    final n = game.boardToLogical(location.getNeighbor(launchDir)) - logicalPos;
    return atan2(n.y, n.x);
  }

  /// 玩家旋轉發射方向（delta = ±1，循環 6 個方向）。
  void rotate(int delta) {
    final vals = HexagonDirection.values;
    launchDir = vals[(launchDir.index + delta) % vals.length];
  }

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;
    if (game.enemies.isEmpty) return; // 沒有敵人時不發射
    direction = _launchAngle;
    // 相鄰有多重箭 → 除了選定方向，再往左右兩側各投一根（三向齊發）。
    final dirs = multishotBuffed
        ? <HexagonDirection>[
            launchDir,
            HexagonDirection.values[(launchDir.index + 1) % 6],
            HexagonDirection.values[(launchDir.index + 5) % 6],
          ]
        : <HexagonDirection>[launchDir];
    for (final d in dirs) {
      _throwLog(d);
    }
    prepareShoot = fireCD.toDouble();
  }

  /// 朝指定六角方向丟一根滾木。
  void _throwLog(HexagonDirection dir) {
    final n = game.boardToLogical(location.getNeighbor(dir)) - logicalPos;
    game.world.add(RollingLogProjectileComponent(
      damage: damage,
      start: logicalPos.clone(),
      speed: 0.9,
      travelAngle: atan2(n.y, n.x),
      originCell: location,
      dirIndex: dir.index, // 對應 spritesheet 的方向列
    ));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // 陰影 + 塔身 sprite
    _renderAimArrow(canvas);
  }

  /// 在塔上畫出目前發射方向的箭頭（點選時橘色高亮，平時淡白提示）。
  void _renderAimArrow(Canvas canvas) {
    final s = game.iso.scaleX;
    final inspected = game.inspecting.value == location;
    final d = game.logicalToScreen(
            game.boardToLogical(location.getNeighbor(launchDir))) -
        game.logicalToScreen(logicalPos);
    final ang = atan2(d.y, d.x);

    final origin = Offset(size.x / 2, size.y / 2); // sprite 中心＝塔腳
    final len = game.board.hexagonRadius * s * (inspected ? 1.5 : 1.0);
    final tip = origin + Offset(cos(ang), sin(ang)) * len;
    final paint = Paint()
      ..color = (inspected ? Colors.orangeAccent : Colors.white)
          .withOpacity(inspected ? 0.95 : 0.45)
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(origin, tip, paint)
      ..drawLine(
          tip, tip + Offset(cos(ang + 2.6), sin(ang + 2.6)) * (9 * s), paint)
      ..drawLine(
          tip, tip + Offset(cos(ang - 2.6), sin(ang - 2.6)) * (9 * s), paint);
  }
}

/// 冰凍塔：場上只要有敵人就放出以自身為中心、會擴張的減速冰環。
class FreezingTowerComponent extends TowerComponent {
  FreezingTowerComponent(BoardPoint location)
      : super(TowerType.freezing, location);

  // 依升級（slow 值越小＝減速越強）。
  @override
  double get range => mod(TowerMod.range, 2.5);
  double get slowFactor => mod(TowerMod.slow, 0.6);
  int get freezeDuration => mod(TowerMod.fdur, 2000).toInt();
  double get vulnAmp => mod(TowerMod.vuln, 0); // 霜牢：脆弱化物理受傷加成

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
      duration: freezeDuration,
      slowFactor: slowFactor,
      vulnAmp: vulnAmp,
    );
  }
}

/// 火焰塔：以最小角度差鎖定敵人，慢慢轉向並持續噴出火焰子彈。
class FlameTowerComponent extends TowerComponent {
  FlameTowerComponent(BoardPoint location) : super(TowerType.flame, location);

  static const double rotateSpeed = 0.08;

  // 依升級：射程 / 灼燒 DPS / 命中後持續燃燒 DPS（0=無，熾流分支給）。
  @override
  double get range => mod(TowerMod.range,4);
  @override
  double get damage => mod(TowerMod.dmg,8);
  double get burnDps => mod(TowerMod.burn,0);

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
      burnDps: burnDps,
    );
  }
}

/// 風刃塔：持續旋轉，對前方扇形範圍內的敵人造成傷害（無子彈）。
class AirBladeTowerComponent extends TowerComponent {
  AirBladeTowerComponent(BoardPoint location)
      : super(TowerType.airBlade, location);

  /// 刀刃旋轉角速度（rad/秒，dt-based → 不受幀率影響）。4π = 每秒 2 圈。
  /// 依升級（疾風系）可轉更快。
  double get spinSpeed => mod(TowerMod.spin,4 * pi);

  // 依升級（巨刃系）擴大攻擊範圍。
  @override
  double get range => mod(TowerMod.range,2.5);

  /// 依升級（亂舞）刀刃片數：每圈對每個敵人掃 bladeCount 次 → DPS ×bladeCount。
  /// 相鄰有多重箭再 +1 片。
  int get bladeCount =>
      mod(TowerMod.blades, 1).toInt() + (multishotBuffed ? 1 : 0);

  /// 依升級（撕裂）每刀疊一層流血，每層每秒傷害（0=無）。
  double get bleedPerStack => mod(TowerMod.bleed, 0);

  double _windEmit = 0;

  @override
  void update(double dt) {
    // dt-based 旋轉，與幀率無關。
    final prev = direction;
    direction = (direction + spinSpeed * dt) % (2 * pi);
    final swept = spinSpeed * dt; // 這一幀前緣掃過的角度

    // 多重刀刃：N 片等角前緣，任一片這一幀掃過敵人就砍一刀。一圈每隻被每片各掃
    // 一次 → 共 N 刀 → DPS ×N。與幀率無關。
    final n = bladeCount;
    final step = 2 * pi / n;
    for (final e in game.enemiesInRange(logicalPos, range)) {
      final diff = e.logicalPos - logicalPos;
      final ang = atan2(diff.y, diff.x);
      for (var k = 0; k < n; k++) {
        var rel = (ang - (prev + k * step)) % (2 * pi);
        if (rel < 0) rel += 2 * pi;
        if (rel > 0 && rel <= swept) {
          e.dealDamage(damage);
          if (bleedPerStack > 0) e.addBleed(kBleedEffectType, bleedPerStack);
          break; // 同一幀最多算一刀，避免重複
        }
      }
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

  static const double slashSpan = 0.95; // 斬擊新月的角度跨度(rad)

  @override
  void render(Canvas canvas) {
    // 斬擊刀光：尖端收尖、中間飽滿的新月刀光(貼地)，外緣有一道亮刀刃，
    // 後方兩道較淡殘影做出揮砍的動態模糊。
    final foot = Offset(size.x / 2, size.y / 2);
    final rOut = game.board.hexagonRadius * 1.4; // 邏輯半徑
    // 每片刀刃各畫一組刀光（前緣最亮、後方兩道漸淡殘影）。
    final step = 2 * pi / bladeCount;
    for (var k = 0; k < bladeCount; k++) {
      final a = direction + k * step;
      _slash(canvas, foot, rOut, a - 0.34, fill: 0.06, edge: 0.0);
      _slash(canvas, foot, rOut, a - 0.17, fill: 0.13, edge: 0.25);
      _slash(canvas, foot, rOut, a, fill: 0.26, edge: 0.8);
    }
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

  // 依升級：連鎖人數 / 麻痺時間 / 單擊傷害。
  // 麻痺「命中必定觸發(100%)」，強弱由麻痺時間(pms)決定；基礎時間很短＝很微弱。
  int get chainLimit => mod(TowerMod.chain,1).toInt();
  double get paralyzeChance => 1.0;
  int get paralyzeMs => mod(TowerMod.pms,500).toInt();
  @override
  double get damage => mod(TowerMod.dmg,10);

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;
    // 相鄰有多重箭 → 同時電最近 2 個目標（各自再連鎖）。
    if (shootNearest(multishotBuffed ? 2 : 1)) {
      prepareShoot = fireCD.toDouble();
    }
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return ThunderProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1,
      target: enemy,
      chainLimit: chainLimit,
      chainDistance: 5,
      paralyzeChance: paralyzeChance,
      paralyzeMs: paralyzeMs,
    );
  }
}

/// 火炮塔：鎖定最近敵人，發射砲彈在落點爆炸造成範圍傷害。
class CannonTowerComponent extends TowerComponent {
  CannonTowerComponent(BoardPoint location) : super(TowerType.cannon, location);

  // 依升級：爆炸半徑（格）/ 中心加成峰值（0=關）。
  double get blastHex => mod(TowerMod.blast,1.2);
  double get centerPeak => mod(TowerMod.center,0);

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;
    // 相鄰有多重箭 → 同時射最近 2 個目標（2 發砲彈）。
    if (shootNearest(multishotBuffed ? 2 : 1)) {
      prepareShoot = fireCD.toDouble();
    }
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return CannonProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 0.6,
      targetPos: enemy.logicalPos.clone(),
      blastHex: blastHex,
      centerPeak: centerPeak,
    );
  }
}

/// 毒塔：鎖定最近敵人，射出毒液使其中毒持續扣血。
class PoisonTowerComponent extends TowerComponent {
  PoisonTowerComponent(BoardPoint location) : super(TowerType.poison, location);

  // 依升級：固定毒傷總量 / 每秒%最大血量 / 中毒持續時間(ms)。
  @override
  double get damage => mod(TowerMod.pdmg,60);
  double get pctPerSec => mod(TowerMod.pct,0.01);
  int get poisonDuration => mod(TowerMod.pdur,3000).toInt();

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;
    // 相鄰有多重箭 → 同時射最近 3 個敵人，否則射最近 1 個。
    if (shootNearest(multishotBuffed ? 3 : 1)) {
      prepareShoot = fireCD.toDouble();
    }
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return PoisonProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1.4,
      target: enemy,
      duration: poisonDuration,
      pctPerSec: pctPerSec,
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

/// 多重箭：支援塔，本身不攻擊；相鄰(6 格)的塔會依塔種被強化（見各塔 update
/// 與 game.multishotAt）。外觀為程式繪製的「向外發散箭頭」佔位圖示。
class MultishotTowerComponent extends TowerComponent {
  MultishotTowerComponent(BoardPoint location)
      : super(TowerType.multishot, location);

  @override
  void update(double dt) {} // 純支援、被動生效，不做任何攻擊

  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final foot = Offset(size.x / 2, size.y / 2);
    // 貼地陰影
    canvas.drawOval(
      Rect.fromCenter(
          center: foot.translate(0, 5 * s), width: 24 * s, height: 11 * s),
      Paint()..color = Colors.black.withOpacity(0.25),
    );
    // 底座
    canvas.drawCircle(foot, 11 * s, Paint()..color = const Color(0xFF5D4037));
    canvas.drawCircle(
      foot,
      11 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = Colors.amber,
    );
    // 三支往上發散的箭（多重箭意象）
    final arrow = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    for (final off in const [-0.6, 0.0, 0.6]) {
      final a = -pi / 2 + off; // 往上為主、左右發散
      final tip = foot + Offset(cos(a), sin(a)) * (16 * s);
      canvas
        ..drawLine(foot, tip, arrow)
        ..drawLine(tip, tip + Offset(cos(a + 2.6), sin(a + 2.6)) * (5 * s),
            arrow)
        ..drawLine(tip, tip + Offset(cos(a - 2.6), sin(a - 2.6)) * (5 * s),
            arrow);
    }
  }
}

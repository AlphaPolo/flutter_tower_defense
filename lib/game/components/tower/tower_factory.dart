import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../constant/game_constant.dart';
import '../../audio/game_audio.dart';
import '../../board/hex.dart';
import '../../effects/particles.dart';
import '../../tower_defense_game.dart';
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
    case TowerType.sniper:
      return SniperTowerComponent(location);
    case TowerType.obstacle:
      return ObstacleTowerComponent(location);
    case TowerType.spike:
    case TowerType.vortex:
    case TowerType.beacon:
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

  /// 在塔腳畫出目前發射方向的箭頭：圓角錐形箭 + 漸層氣泡質感（無深色外框）。
  /// 大小固定、限制在格內；點選時橘色高亮、平時淡白提示。
  void _renderAimArrow(Canvas canvas) {
    final s = game.iso.scaleX;
    final inspected = game.inspecting.value == location;
    final d = game.logicalToScreen(
            game.boardToLogical(location.getNeighbor(launchDir))) -
        game.logicalToScreen(logicalPos);
    final ang = atan2(d.y, d.x);
    final u = Offset(cos(ang), sin(ang)); // 方向
    final perp = Offset(-sin(ang), cos(ang)) * 0.7; // 壓扁 → 貼地感
    final foot = Offset(size.x / 2, size.y / 2); // sprite 中心＝塔腳

    // 尺寸固定且較短，讓箭頭不突出格子；頭偏鈍 + 圓角描邊柔化。
    final len = game.board.hexagonRadius * s * 0.6;
    final start = 4.0 * s;
    final headLen = 8.0 * s;
    final headHalf = 5.5 * s;
    final shaftHalf = 2.0 * s;
    final neck = len - headLen;

    Offset at(double x, double y) => foot + u * x + perp * y;
    final path = Path()
      ..moveTo(at(start, -shaftHalf).dx, at(start, -shaftHalf).dy)
      ..lineTo(at(neck, -shaftHalf).dx, at(neck, -shaftHalf).dy)
      ..lineTo(at(neck, -headHalf).dx, at(neck, -headHalf).dy)
      ..lineTo(at(len, 0).dx, at(len, 0).dy)
      ..lineTo(at(neck, headHalf).dx, at(neck, headHalf).dy)
      ..lineTo(at(neck, shaftHalf).dx, at(neck, shaftHalf).dy)
      ..lineTo(at(start, shaftHalf).dx, at(start, shaftHalf).dy)
      ..close();

    final rim = 2.5 * s; // 圓角描邊：膨脹＋磨圓銳角
    final bounds = path.getBounds().inflate(rim + 3 * s);
    final groupAlpha = inspected ? 1.0 : 0.55;

    // saveLayer 套群組透明度 → 內部畫不透明、疊層不接縫。
    canvas.saveLayer(
        bounds, Paint()..color = Colors.white.withValues(alpha: groupAlpha));

    // 柔和貼地陰影
    canvas.drawPath(
      path.shift(Offset(0, 1.5 * s)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
    );

    // 漸層氣泡填色（左上高光 → 中間主色 → 邊緣深色）
    final grad = RadialGradient(
      center: const Alignment(-0.3, -0.6),
      radius: 1.0,
      colors: inspected
          ? const [Color(0xFFFFEFC2), Color(0xFFF7A81E), Color(0xFFDE7A12)]
          : const [Colors.white, Color(0xFFE9F0F8), Color(0xFFB7C6D8)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(bounds);
    final fillPaint = Paint()..shader = grad;
    final roundStroke = Paint()
      ..shader = grad
      ..style = PaintingStyle.stroke
      ..strokeWidth = rim
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(path, fillPaint)
      ..drawPath(path, roundStroke);

    canvas.restore();
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

  /// 兩角度的「最短差」，正規化到 [-π, π]：跨越 ±π 邊界時（例如 172° → -172°）
  /// 取近路的 ±16°，而不是繞遠路的 344°。
  static double _angleDelta(double to, double from) {
    var d = (to - from) % (2 * pi);
    if (d > pi) d -= 2 * pi;
    if (d < -pi) d += 2 * pi;
    return d;
  }

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());

    // 標靶模式：轉向標靶後持續噴（不需要敵人；波間停火）。
    final beacon = beaconLogical;
    if (beacon != null) {
      target = null;
      final diffB = beacon - logicalPos;
      if (diffB.length2 > 0) {
        final delta = _angleDelta(atan2(diffB.y, diffB.x), direction);
        final amount = min(rotateSpeed, delta.abs());
        direction += delta.sign * amount;
        direction = _angleDelta(direction, 0);
      }
      if (!game.waveRunning.value || prepareShoot > 0) return;
      final fix = (Random().nextDouble() * 0.4) - 0.2;
      game.world.add(FlameProjectileComponent(
        damage: damage,
        start: muzzle(),
        speed: 0.5,
        travelAngle: direction + fix,
        lengthHex: range / 2,
        burnDps: burnDps,
      ));
      prepareShoot = fireCD.toDouble();
      return;
    }

    final t = target;
    if (t != null) {
      if (!t.isDead && t.isMounted) {
        final diff = t.logicalPos - logicalPos;
        if (game.isInsideRange(diff, range)) {
          final targetAngle = atan2(diff.y, diff.x);
          // 最短差 → 永遠往離目前砲口最近的方向轉。
          final delta = _angleDelta(targetAngle, direction);
          final amount = min(rotateSpeed, delta.abs());
          direction += delta.sign * amount;
          // 累積後拉回 [-π, π]，避免之後的比較再跨界。
          direction = _angleDelta(direction, 0);
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
      final d = _angleDelta(a, direction).abs(); // 同樣用最短差挑「轉最少」的目標
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

  // 一片刀刃（3 道殘影 + 亮刃）在 flat 座標烘成的共用圖：幾何與 SweepGradient 在本地
  // 座標是固定的、只有旋轉每幀變，故烘一次、之後每片只 drawImageRect + 旋轉貼上。
  // → 免掉每幀每塔的 SweepGradient 配置與逐像素填色（拉近時最貴的部分）。
  static ui.Image? _bladeImage;
  static double _bladeR = -1; // 烘圖時的 rOut；換棋盤尺寸時重烘
  static double _bladeHalf = 0; // 貼圖時的邏輯半尺寸（弧心到影像邊）
  static final Paint _bladePaint = Paint()..filterQuality = FilterQuality.low;

  /// 取得（必要時烘出）共用刀刃圖。以弧心為影像中心，前緣在 0、殘影在 -0.17/-0.34
  /// （與舊繪製的相對關係一致），貼圖時整片再旋轉 direction+k*step。
  ui.Image _bakedBlade() {
    final rOut = game.board.hexagonRadius * 1.4;
    final cached = _bladeImage;
    if (cached != null && _bladeR == rOut) return cached;
    _bladeImage?.dispose();
    const pad = 6.0; // 亮刃 stroke + AA 外擴（邏輯單位）
    _bladeHalf = rOut + pad;
    // 以 iso 基向量長度當超取樣倍率 → 影像像素貼近螢幕像素，不因 iso 放大而糊。
    final double res =
        max(game.iso.axisX.length, game.iso.axisY.length).clamp(1.0, 3.0);
    final side = (_bladeHalf * 2 * res).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(side / 2, side / 2) // 原點＝弧心
      ..scale(res); // 之後 _slash 直接用邏輯座標繪製（放大到影像解析度）
    _slash(canvas, rOut, -0.34, fill: 0.06, edge: 0.0);
    _slash(canvas, rOut, -0.17, fill: 0.13, edge: 0.25);
    _slash(canvas, rOut, 0.0, fill: 0.26, edge: 0.8);
    _bladeR = rOut;
    return _bladeImage = recorder.endRecording().toImageSync(side, side);
  }

  @override
  void render(Canvas canvas) {
    // 斬擊刀光：把烘好的一片刀刃圖，依 iso 貼地角度 + 旋轉，每片各貼一次。
    final img = _bakedBlade();
    final foot = Offset(size.x / 2, size.y / 2);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    // dst 用「邏輯」尺寸（影像在螢幕的大小交給下面的 iso 變換縮放）。
    final dst = Rect.fromCenter(
        center: Offset.zero, width: _bladeHalf * 2, height: _bladeHalf * 2);
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final step = 2 * pi / bladeCount;
    for (var k = 0; k < bladeCount; k++) {
      canvas
        ..save()
        ..translate(foot.dx, foot.dy)
        ..transform(Float64List.fromList([
          ax.x, ax.y, 0, 0, //
          ay.x, ay.y, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]))
        ..rotate(direction + k * step)
        ..drawImageRect(img, src, dst, _bladePaint)
        ..restore();
    }
    super.render(canvas);
  }

  /// 烘圖用：在 flat 座標畫一道新月刀光（前緣最亮，沿弧線往後漸淡）。旋轉 [a0] 為
  /// 相對角（貼地 iso 與整片旋轉由 render() 統一處理）。SweepGradient 只在烘圖時配置。
  void _slash(
    Canvas canvas,
    double rOut,
    double a0, {
    required double fill,
    required double edge,
  }) {
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
        colors: [for (final o in ops) c.withValues(alpha: o * a)],
        stops: stops,
      ).createShader(rect);
    }

    canvas
      ..save()
      ..rotate(a0); // 相對旋轉；貼地 iso 與整片旋轉由 render() 統一處理
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

    // 標靶模式：波次中持續砲擊標靶落點；超出射程 → 朝該方向打「極限射程」處。
    final beacon = beaconLogical;
    if (beacon != null) {
      if (!game.waveRunning.value) return;
      final diff = beacon - logicalPos;
      if (diff.length2 == 0) return;
      final maxLen = game.board.hexagonRadius * range;
      final tp = diff.length > maxLen
          ? logicalPos + diff.normalized() * maxLen
          : beacon.clone();
      direction = atan2(diff.y, diff.x);
      game.world.add(CannonProjectileComponent(
        damage: damage,
        start: logicalPos.clone(),
        speed: 0.6,
        targetPos: tp,
        blastHex: blastHex,
        centerPeak: centerPeak,
      ));
      GameAudio.fire(type, position);
      prepareShoot = fireCD.toDouble();
      return;
    }

    // 相鄰有多重箭 → 同時射最近 2 個目標（2 發砲彈）。
    if (shootNearest(multishotBuffed ? 2 : 1)) {
      prepareShoot = fireCD.toDouble();
    }
  }

  @override
  ProjectileComponent createProjectile(EnemyComponent enemy) {
    return CannonProjectileComponent(
      damage: damage,
      start: logicalPos.clone(), // 塔中心；出膛高度由砲彈自身抬到塔頂
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
/// 與 game.multishotAt）。外觀＝Kenney UFO-A 3D 素材（懸浮支援建築），
/// 沿用基底 render（陰影 + sprite）。
class MultishotTowerComponent extends TowerComponent {
  MultishotTowerComponent(BoardPoint location)
      : super(TowerType.multishot, location);

  @override
  double get spriteScale => 0.65; // UFO 素材偏大 → 縮小，與其他塔更協調

  @override
  void update(double dt) {} // 純支援、被動生效，不做任何攻擊
}

/// 狙擊塔：全圖射程、高傷慢速的單發弩箭塔。
///
/// - 鎖定「場上當前血量最高」且射線不被**高聳地形**（blocksSight：巨石/密林）
///   遮擋的敵人（玩家建築與水面永不遮擋；「彈道破除」分支後地形也不遮擋）。
/// - 瞄準 0.8 秒（紅色雷射漸亮）後朝目標方向射出一支高速弩箭
///   （直線飛行、不追蹤），之後進入裝填 CD。
/// - 傷害在弩箭「命中當下」逐敵結算（見 SniperBoltProjectileComponent）：
///   獵首（血量比例 ≥ [huntTh] → ×1.5）、神射手對重型 ×(1+[heavyMul])。
/// - 貫穿(Lv3)：弩箭貫穿沿途全部敵人直到彈道終點；否則命中第一個即消失。
/// - 主動技（skillMul>0 解鎖）：[castSkillAt] 朝指定方向立刻射擊，
///   CD（10 秒）與普攻裝填**各自獨立**。
class SniperTowerComponent extends TowerComponent {
  SniperTowerComponent(BoardPoint location) : super(TowerType.sniper, location);

  /// 瞄準時間（ms）、主動技 CD（ms）與弩箭速度（speed/3 = px/ms，全場最快）。
  static const double aimMs = 800;
  static const double skillCdMs = 10000;
  static const double boltSpeed = 5;

  // 依升級的有效數值。
  @override
  double get damage => mod(TowerMod.dmg, 90);
  double get huntTh => mod(TowerMod.huntTh, 0.8);
  bool get losFree => mod(TowerMod.losFree, 0) > 0;
  bool get pierce => mod(TowerMod.pierce, 0) > 0;
  double get heavyMul => mod(TowerMod.heavyMul, 0);
  double get skillMul => mod(TowerMod.skillMul, 0);
  double get distRamp => mod(TowerMod.distRamp, 0);

  /// 主動技狀態（UI 顯示按鈕 / CD 用）。
  bool get skillUnlocked => skillMul > 0;
  double skillCdLeft = 0;
  bool get skillReady => skillUnlocked && skillCdLeft <= 0;

  /// 瞄準倒數（>0＝瞄準中）；[aimProgress] 0→1 給雷射漸亮用。
  double _aimLeft = 0;
  double get aimProgress => 1 - (_aimLeft / aimMs).clamp(0.0, 1.0);
  bool get aiming => target != null && _aimLeft > 0;

  /// 射線最長邏輯距離（蓋過整張棋盤即可）。
  double get _maxRay =>
      game.board.hexagonRadius * (TowerDefenseGame.boardRadius * 4 + 4);

  /// 雷射/彈道的螢幕起點（塔頂砲口附近）。
  Vector2 get beamOriginScreen => position + Vector2(0, -size.y * 0.16);

  @override
  void update(double dt) {
    final ms = dt * 1000;
    skillCdLeft = (skillCdLeft - ms).clamp(0, skillCdMs);
    prepareShoot = (prepareShoot - ms).clamp(0, fireCD.toDouble());

    final t = target;
    if (t != null && beaconTarget != null) {
      // 剛設定標靶 → 中斷進行中的敵人瞄準。
      target = null;
      _aimLeft = 0;
      return;
    }
    if (t != null) {
      // 瞄準中：目標死亡 / 離場 / 失去視線 → 放棄重瞄（不進 CD）。
      if (t.isDead ||
          !t.isMounted ||
          (!losFree && game.terrainBlocksLine(logicalPos, t.logicalPos))) {
        target = null;
        _aimLeft = 0;
        return;
      }
      final diff = t.logicalPos - logicalPos;
      direction = atan2(diff.y, diff.x);
      _aimLeft -= ms;
      if (_aimLeft <= 0) {
        _fireAt(t);
        target = null;
        prepareShoot = fireCD.toDouble(); // 開火後才進裝填
      }
      return;
    }

    if (prepareShoot > 0) return;

    // 標靶模式：放棄敵人瞄準，波次中持續朝標靶射擊。
    // 節奏＝瞄準時間＋裝填（與一般「瞄準→開火」週期等速，平衡中立）。
    final beacon = beaconLogical;
    if (beacon != null) {
      if (!game.waveRunning.value) return;
      final dirV = beacon - logicalPos;
      if (dirV.length2 == 0) return;
      _launch(dirV.normalized(), mul: 1);
      prepareShoot = fireCD + aimMs;
      return;
    }

    final next = _pickTarget();
    if (next == null) return;
    target = next;
    _aimLeft = aimMs;
    game.world.add(SniperAimLaserComponent(this));
  }

  /// 血量最高優先；被地形擋住就退而求其次找下一個看得到的。
  EnemyComponent? _pickTarget() {
    final sorted = game.enemies
        .where((e) => !e.isDead && e.isMounted)
        .sortedBy<num>((e) => -e.status.currentHp);
    for (final e in sorted) {
      if (losFree || !game.terrainBlocksLine(logicalPos, e.logicalPos)) {
        return e;
      }
    }
    return null;
  }

  /// 普攻開火：朝鎖定目標「當下位置」的方向射出弩箭（直線、不追蹤）。
  void _fireAt(EnemyComponent primary) {
    final dirV = primary.logicalPos - logicalPos;
    if (dirV.length2 == 0) return;
    _launch(dirV.normalized(), mul: 1);
  }

  /// 主動技：朝 [aimLogical] 的方向立刻射擊。回傳是否成功施放（CD 未好回 false）。
  /// 沒命中也照樣消耗 CD（玩家自己瞄）。是否穿透 / 無視地形沿用目前升級。
  bool castSkillAt(Vector2 aimLogical) {
    if (!skillReady) return false;
    final dirV = aimLogical - logicalPos;
    if (dirV.length2 == 0) return false;
    _launch(dirV.normalized(), mul: skillMul);
    skillCdLeft = skillCdMs;
    game.towerChanged.value++; // 面板刷新技能 CD
    return true;
  }

  /// 朝單位方向 [u] 射出一支弩箭（傷害倍率 [mul]）。彈道終點先算好：
  /// 撞到擋路地形截斷（「彈道破除」則直達場邊）；命中判定由弩箭飛行時逐幀處理。
  void _launch(Vector2 u, {required double mul}) {
    direction = atan2(u.y, u.x);
    var end = game.rayEnd(logicalPos, u, _maxRay, ignoreTerrain: losFree);
    // 標靶樁是實體擋箭物：未貫穿的弩箭飛到彈道上第一根標靶樁即停；
    // 貫穿(Lv3)則穿過。一般射擊與主動技一體適用（物理一致）。
    if (!pierce) {
      final lane = game.board.hexagonRadius * 0.45; // 彈道判寬
      var bestLen = (end - logicalPos).length;
      for (final b in game.beaconLogicalPositions()) {
        final v = b - logicalPos;
        final along = v.dot(u);
        if (along <= 0 || along >= bestLen) continue;
        if ((v - u * along).length <= lane) {
          bestLen = along;
          end = logicalPos + u * along;
        }
      }
    }
    game.world.add(SniperBoltProjectileComponent(
      damage: damage * mul,
      start: logicalPos.clone(),
      speed: boltSpeed,
      end: end,
      huntTh: huntTh,
      heavyMul: heavyMul,
      pierce: pierce,
      distRamp: distRamp,
    ));
    GameAudio.fire(type, position);
  }
}

/// 狙擊塔瞄準雷射：瞄準期間從塔頂到目標畫一條漸亮的細紅線＋目標收束圈。
/// 世界元件（畫在單位之上），塔停止瞄準或離場即自毀。
class SniperAimLaserComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  SniperAimLaserComponent(this.tower);
  final SniperTowerComponent tower;

  @override
  void onMount() {
    super.onMount();
    priority = 1999998; // 高於場上單位，略低於飛行子彈
  }

  @override
  void update(double dt) {
    if (!tower.isMounted || !tower.aiming) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = tower.target;
    if (t == null || !t.isMounted) return;
    final s = game.iso.scaleX;
    final p = tower.aimProgress; // 0→1 漸亮
    final from = tower.beamOriginScreen;
    final to = game.logicalToScreen(t.logicalPos) - Vector2(0, 10 * s);
    final a = Offset(from.x, from.y);
    final b = Offset(to.x, to.y);
    final alpha = 0.15 + 0.55 * p;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: alpha)
        ..strokeWidth = (0.8 + 1.2 * p) * s
        ..strokeCap = StrokeCap.round,
    );
    // 目標收束圈：由大縮小到貼身，開火前一刻最小最亮。
    final r = (14 - 8 * p) * s;
    canvas.drawCircle(
      b,
      r,
      Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * s,
    );
  }
}


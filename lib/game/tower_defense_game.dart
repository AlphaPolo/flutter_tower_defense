import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'
    show FrictionSimulation, Simulation, SpringDescription, SpringSimulation;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/my_app.dart' show showTopMessage;
import 'audio/game_audio.dart';
import 'board/hex.dart';
import 'board/pathfinding.dart';
import 'components/board_component.dart';
import 'components/enemy_component.dart';
import 'components/environment.dart';
import 'components/enemy_kind.dart';
import 'components/tower/tower_component.dart';
import 'components/tower/tower_factory.dart';
import 'components/trap/trap_component.dart';
import 'components/wave_spawner.dart';
import 'demo/auto_player.dart';
import 'effects/camera_shake.dart';
import 'effects/particles.dart';
import 'iso/iso_projection.dart';
import 'tower_type.dart';

/// 整個塔防遊戲的 FlameGame（isometric 版）。
///
/// 遊戲邏輯（移動、射程、瞄準、尋路）全部在「top-down 邏輯座標」進行；
/// [iso] 只在繪製時把邏輯座標投影成 isometric 螢幕座標。棋盤是預先用
/// Blender 渲染好的一張 isometric 圖。
class TowerDefenseGame extends FlameGame with ScrollDetector, ScaleDetector {
  TowerDefenseGame({this.withEnvironment = true});

  /// 是否在開局隨機佈置天然環境（測試/模擬設 false 以保持穩定）。
  final bool withEnvironment;

  static const int boardRadius = 5;
  static const double hexRadius = 32;
  static const double hexMargin = 4;

  late final Board board;
  late final IsoProjection iso;
  late final BoardPoint spawnLocation;
  late final BoardPoint targetLocation;

  /// 每個格子要往哪個方向走（從終點往回算的 flow field）。
  Map<BoardPoint, HexagonDirection> guide = {};

  /// 出生點沿 flow field 走到終點的實際路線（給地面路徑顯示用）。
  List<BoardPoint> route = [];

  /// 場上的敵人與塔（元件自行在 onMount / onRemove 時登記）。
  final List<EnemyComponent> enemies = [];
  final Map<BoardPoint, TowerComponent> towers = {};

  /// 陷阱（地刺等）。獨立於 [towers]，因此尋路 [isPointCanMove] 看不到它，
  /// 不會阻擋敵人、可蓋在路徑上。
  final Map<BoardPoint, TrapComponent> traps = {};

  /// 每場隨機佈置的天然環境（擋路的會擋路、不擋路的有經過效果）。一律不可建塔。
  final Map<BoardPoint, EnvType> environment = {};

  late final BoardComponent boardComponent;

  /// 相機震動（火炮落地爆炸等會觸發）。
  final CameraShakeController cameraShake = CameraShakeController();

  // ── isometric 素材 ───────────────────────────────────────
  final Images isoImages = Images(prefix: 'assets/iso/');
  late final Sprite boardSprite;
  late final Map<TowerType, Sprite> towerSprites;
  late final List<Sprite> obstacleSprites;
  late final Sprite treeSprite; // 密林(woods)天然環境用
  late final Sprite rockSprite; // 巨石(boulder)天然環境用
  late final Sprite thornsSprite; // 荊棘(thorns)天然環境用
  late final Sprite mudSprite; // 泥沼(mud)天然環境用
  late final Sprite spikeTrapSprite; // 地刺陷阱(spike)用

  // 塔陰影：塔不會動、所有塔陰影同形，故起動時把「模糊好的貼地橢圓」烘成一張圖，
  // 之後每座塔每幀只用便宜的 drawImageRect 貼上 → 免掉每幀 50+ 個 MaskFilter.blur。
  late final ui.Image towerShadowImage;
  late final Offset towerShadowAnchor; // 影像內對應「塔腳」的像素座標

  // ── 粒子特效素材 ─────────────────────────────────────────
  final Images fxImages = Images(prefix: 'assets/fx/');
  late final SpriteAnimation dustAnim; // 敵人出場的塵土特效（一次性）

  /// 敵人直立動畫 spritesheet（水平幀條），依 EnemyKind.id 索引；沒有的用顏色圓。
  final Map<String, ui.Image> enemySheets = {};

  /// 滾木滾動 spritesheet（6 列方向 × 8 欄幀，每格 96px）。
  late final ui.Image logSheet;

  /// 爆炸動畫 spritesheet（火炮落地用，10 幀 × 192px）。
  late final ui.Image explosionSheet;

  /// 水池動態水面 shader（載入失敗則為 null → 水池退回平面繪製）。
  ui.FragmentProgram? waterProgram;
  static const int logDirCount = 6;
  static const int logFrameCount = 8;
  static const double logCell = 96;

  // ── 波次 ─────────────────────────────────────────────────
  static const int totalWaves = 25;
  int waveNumber = 0;
  int completedWaves = 0;
  WaveSpawnerComponent? _spawner;

  // ── 給 UI overlay 監聽的狀態 ──────────────────────────────
  final ValueNotifier<int> coin = ValueNotifier(150);
  final ValueNotifier<int> heart = ValueNotifier(20);
  final ValueNotifier<int> freeObstacle = ValueNotifier(3);
  final ValueNotifier<bool> cheat = ValueNotifier(false);
  // 開關：開啟後噴火塔特效變淡（提高透明度），預設關（原亮度）。
  final ValueNotifier<bool> dimFlame = ValueNotifier(false);
  // 開關：水面倒影（逐像素折射）。預設開；效能吃緊可關 → 水面照舊、只省倒影運算。
  final ValueNotifier<bool> waterReflection = ValueNotifier(true);
  final ValueNotifier<TowerType?> selecting = ValueNotifier(null);
  // 目前被點選查看的「已蓋建築」格子（顯示資訊面板 + 拆除按鈕）。
  final ValueNotifier<BoardPoint?> inspecting = ValueNotifier(null);
  // 敵人圖鑑：目前被點選查看特性的敵人種類（null = 未開）。
  final ValueNotifier<EnemyKind?> inspectingEnemy = ValueNotifier(null);
  // 塔升級 / 狀態改變的通知（讓資訊面板重繪）。
  final ValueNotifier<int> towerChanged = ValueNotifier(0);
  final ValueNotifier<int> wave = ValueNotifier(0);
  final ValueNotifier<bool> waveRunning = ValueNotifier(false);
  final ValueNotifier<bool> gameOver = ValueNotifier(false);
  final ValueNotifier<bool> gameWon = ValueNotifier(false);
  // 密林收入事件（序號, 金額）：HUD 據此在金幣旁播「+xx 從密林」浮動提示；
  // 序號每波遞增 → 金額相同也會觸發通知重播。
  final ValueNotifier<(int, int)?> woodsIncome = ValueNotifier(null);

  /// 玩家遊戲速度（1/2/3×）：與 demoSpeed 相乘決定每幀模擬子步數。
  final ValueNotifier<int> gameSpeed = ValueNotifier(1);

  // ── 無盡模式 ─────────────────────────────────────────────
  /// true＝無盡模式（開打前由 UI 選擇；無勝利條件、25 波後難度續漲）。
  final ValueNotifier<bool> endless = ValueNotifier(false);

  /// 無盡模式最佳紀錄（撐過幾波），啟動時從本機載入、破紀錄即寫回。
  final ValueNotifier<int> bestEndless = ValueNotifier(0);

  /// 本場是否刷新了無盡紀錄（結束彈窗顯示「新紀錄！」用）。
  bool newEndlessRecord = false;

  // ── 自動演示 ──────────────────────────────────────────────
  final ValueNotifier<bool> demoRunning = ValueNotifier(false);
  AutoPlayerComponent? _autoPlayer;
  int demoSpeed = 1; // 演示時把每幀模擬步數加倍 → 加速播放（每步仍用正常 dt）

  @override
  Future<void> onLoad() async {
    _loadBestEndless();
    board = Board(
      boardRadius: boardRadius,
      hexagonRadius: hexRadius,
      hexagonMargin: hexMargin,
    );
    targetLocation = const BoardPoint(0, -boardRadius);
    spawnLocation = const BoardPoint(0, boardRadius);
    recomputeGuide();

    final jsonStr = await rootBundle.loadString('assets/iso/board.json');
    iso = IsoProjection.fromJson(jsonStr, board);

    boardSprite = await Sprite.load('board.png', images: isoImages);
    obstacleSprites = [
      for (var i = 0; i < 4; i++)
        await Sprite.load('obstacle_$i.png', images: isoImages),
    ];
    towerSprites = {
      TowerType.flame: await Sprite.load('tower_flame.png', images: isoImages),
      TowerType.freezing:
          await Sprite.load('tower_freezing.png', images: isoImages),
      TowerType.airBlade:
          await Sprite.load('tower_airblade.png', images: isoImages),
      TowerType.thunder:
          await Sprite.load('tower_thunder.png', images: isoImages),
      TowerType.cannon:
          await Sprite.load('tower_cannon.png', images: isoImages),
      TowerType.poison:
          await Sprite.load('tower_poison.png', images: isoImages),
      TowerType.log: await Sprite.load('tower_log.png', images: isoImages),
      TowerType.obstacle: obstacleSprites.first,
      // 多重箭：Kenney UFO-A 3D 素材（懸浮支援建築）。
      TowerType.multishot:
          await Sprite.load('tower_multishot.png', images: isoImages),
      // 狙擊塔：KayKit Medieval Hexagon 塔座（tower_base_red）＋
      // Kenney 弩砲（weapon-ballista），與火炮塔同視覺家族。
      TowerType.sniper:
          await Sprite.load('tower_sniper.png', images: isoImages),
    };
    treeSprite = await Sprite.load('tree.png', images: isoImages);
    rockSprite = await Sprite.load('rock.png', images: isoImages);
    thornsSprite = await Sprite.load('thorns.png', images: isoImages);
    mudSprite = await Sprite.load('mud.png', images: isoImages);
    spikeTrapSprite = await Sprite.load('trap_spike.png', images: isoImages);
    final dustImg = await fxImages.load('dust.png');
    dustAnim = SpriteAnimation.fromFrameData(
      dustImg,
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: 0.045,
        textureSize: Vector2.all(64),
        loop: false,
      ),
    );
    logSheet = await isoImages.load('log_roll.png');
    explosionSheet = await isoImages.load('explosion.png');
    try {
      waterProgram =
          await ui.FragmentProgram.fromAsset('assets/shaders/water.frag');
    } catch (_) {
      waterProgram = null; // shader 不可用時退回平面水池
    }
    for (final k in [
      ...EnemyKind.all,
      EnemyKind.juggernaut,
      EnemyKind.spiderling, // 分裂產生、不在 all，但需載入貼圖
    ]) {
      final sheet = k.sheet;
      if (sheet != null) enemySheets[k.id] = await isoImages.load(sheet);
    }
    _bakeTowerShadow();

    world.add(BackgroundTapCatcher());
    boardComponent = BoardComponent();
    await world.add(boardComponent);
    add(cameraShake); // 掛在遊戲根層，直接抖動 camera.viewfinder

    if (withEnvironment) generateEnvironment(); // 每場隨機天然環境

    _fitCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _fitCamera();
  }

  /// 全棋盤剛好入鏡的 zoom（_fitCamera 算出、隨視窗尺寸更新）＝拉遠下限。
  double _fitZoom = 0.1;

  void _fitCamera() {
    final s = iso.imageSize;
    camera.viewfinder.position = Vector2(s.x / 2, s.y / 2);
    _fitZoom = min(size.x / s.x, size.y / s.y) * 0.95;
    camera.viewfinder.zoom = _fitZoom;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    final next = camera.viewfinder.zoom * (delta > 0 ? 0.9 : 1.1);
    camera.viewfinder.zoom = next.clamp(_fitZoom, 3.0);
  }

  // ── 觸控：雙指縮放、單指平移 ──────────────────────────────
  double _startZoom = 1;

  /// 相機物理總開關：甩動慣性 / 邊界回彈 / 拖曳出界阻力。
  /// 想整套拿掉（回到純 1:1 無界拖曳）只要改成 false。
  static const bool kCameraPhysics = true;

  // 甩動慣性 + 邊界回彈：放開手指後相機以摩擦力滑行；滑出邊界（棋盤圖範圍）時該軸
  // 帶著當下速度切換成「錨在邊界上」的彈簧 → 衝出一小段被拉回、停在邊界上
  // （iOS rubber band）。x/y 兩軸獨立模擬 → 保留甩動方向、可只有一軸撞牆。
  _CameraFling? _flingX, _flingY;

  /// 邊界回彈彈簧（與 Flutter BouncingScrollSimulation 同款參數；ratio>1 略過阻尼
  /// → 平滑拉回、不來回震盪）。
  static final SpringDescription _bounceSpring =
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 100, ratio: 1.1);

  /// 相機中心的允許範圍：x 取棋盤圖全寬；y 上下各內縮 15%（棋盤圖上下留白較多，
  /// 全幅會滑出太多黑邊）。拖曳阻力、放手回彈、甩動撞界都用同一組邊界。
  Rect get _cameraBounds {
    final s = iso.imageSize;
    return Rect.fromLTRB(0, s.y * 0.15, s.x, s.y * 0.85);
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startZoom = camera.viewfinder.zoom;
    _flingX = null; // 一碰螢幕就停止慣性滑行（和原生捲動一致）
    _flingY = null;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (info.pointerCount > 1) {
      // 雙指 → 縮放（用整體 pinch 距離，往外張放大、捏合縮小，與方向無關）
      camera.viewfinder.zoom =
          (_startZoom * info.raw.scale).clamp(_fitZoom, 3.0);
    } else {
      // 單指 → 平移（螢幕位移換算成世界位移）；拖出邊界時套 rubber band 阻力。
      final zoom = camera.viewfinder.zoom;
      final d = -info.delta.global / zoom;
      final pos = camera.viewfinder.position;
      final b = _cameraBounds;
      camera.viewfinder.position = Vector2(
        _dragAxis(pos.x, d.x, b.left, b.right, size.x / zoom),
        _dragAxis(pos.y, d.y, b.top, b.bottom, size.y / zoom),
      );
    }
  }

  /// 單軸拖曳（帶界外阻力）：界內 1:1；跨出邊界的那段開始「越拖越重」——阻力係數
  /// 同 Flutter BouncingScrollPhysics.frictionFactor＝0.52·(1−越界量/視口)²（視口
  /// 取該軸可見世界寬度）；往界內拉回則不阻，內容快速跟回（同原生手感）。
  double _dragAxis(
      double pos, double delta, double lo, double hi, double viewport) {
    if (!kCameraPhysics) return pos + delta; // 開關關閉 → 純 1:1 無界拖曳
    var x = pos;
    var d = delta;
    if (d == 0) return x;
    // 界外往回拉：先 1:1 自由移動到邊界（拉回不阻）。
    if ((x < lo && d > 0) || (x > hi && d < 0)) {
      final free = (x < lo ? lo : hi) - x; // 與 d 同號
      if (d.abs() <= free.abs()) return x + d;
      x += free;
      d -= free;
    }
    // 界內：自由移動；這一步若會跨出邊界，只把「越界的那段」留給下面的阻力。
    if (x >= lo && x <= hi) {
      final target = x + d;
      if (target >= lo && target <= hi) return target;
      final edge = target < lo ? lo : hi;
      d = target - edge;
      x = edge;
    }
    // 剩餘位移全在界外 → 套阻力（越界越多、係數越小、拖起來越重）。
    final over = x < lo ? lo - x : (x > hi ? x - hi : 0.0);
    final t = 1 - (over / viewport).clamp(0.0, 1.0);
    return x + d * 0.52 * t * t;
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    if (!kCameraPhysics) return; // 開關關閉 → 無慣性、無回彈
    // 放開瞬間的速度（螢幕 px/s）→ 換算成世界速度，方向同 onScaleUpdate 的平移。
    final v = info.raw.velocity.pixelsPerSecond;
    final zoom = camera.viewfinder.zoom;
    final vx = -v.dx / zoom, vy = -v.dy / zoom;
    final pos = camera.viewfinder.position;
    final b = _cameraBounds;
    final outside = pos.x < b.left ||
        pos.x > b.right ||
        pos.y < b.top ||
        pos.y > b.bottom;
    // 太慢（近似輕點/慢放）且在邊界內 → 不需要慣性也不需要回彈。
    // 被拖出邊界時即使速度為 0 也要點火 → 第一幀就切彈簧拉回（同原生放手回彈）。
    if (vx * vx + vy * vy < 60 * 60 && !outside) return;
    const drag = 0.04; // 抗力係數：越小阻力越大、滑越近（0.135＝Flutter 捲動預設）
    _flingX = _CameraFling(FrictionSimulation(drag, pos.x, vx));
    _flingY = _CameraFling(FrictionSimulation(drag, pos.y, vy));
  }

  /// 甩動慣性：每幀推進兩軸模擬、更新相機位置；兩軸都停穩才結束。
  /// 用真實 dt（與 demoSpeed 無關，慣性是 UI 手感、不隨演示加速）。
  void _advanceFling(double dt) {
    final fx = _flingX, fy = _flingY;
    if (fx == null || fy == null) return;
    final b = _cameraBounds;
    camera.viewfinder.position = Vector2(
      _advanceAxis(fx, dt, b.left, b.right),
      _advanceAxis(fy, dt, b.top, b.bottom),
    );
    if (fx.sim.isDone(fx.t) && fy.sim.isDone(fy.t)) {
      _flingX = null;
      _flingY = null;
    }
  }

  /// 推進單軸：摩擦滑行中越過 [lo,hi] 邊界 → 帶著當下速度切換成「錨在邊界上」的
  /// 彈簧（衝出一小段被拉回、停在邊界）。回傳該軸目前位置。
  double _advanceAxis(_CameraFling f, double dt, double lo, double hi) {
    f.t += dt;
    var x = f.sim.x(f.t);
    if (!f.bouncing && (x < lo || x > hi)) {
      final edge = x < lo ? lo : hi;
      f.sim = SpringSimulation(_bounceSpring, x, edge, f.sim.dx(f.t));
      f.t = 0;
      f.bouncing = true;
      x = f.sim.x(0);
    }
    return x;
  }

  // ── 座標換算 ──────────────────────────────────────────────
  /// 邏輯（top-down）座標 — 給遊戲邏輯用。
  Vector2 boardToLogical(BoardPoint bp) {
    final o = board.boardPointToOffset(bp);
    return Vector2(o.dx, o.dy);
  }

  /// isometric 螢幕座標 — 給繪製用。
  Vector2 boardToScreen(BoardPoint bp) =>
      (iso.cellScreen[bp] ?? logicalToScreen(boardToLogical(bp))).clone();

  Vector2 logicalToScreen(Vector2 logical) => iso.logicalToScreen(logical);

  BoardPoint? screenToBoard(Vector2 screen) =>
      board.pointToBoardPoint(_toOffset(iso.screenToLogical(screen)));

  Offset _toOffset(Vector2 v) => Offset(v.x, v.y);

  /// 兩邏輯點之間是否被「高聳天然地形（blocksSight）」遮擋——巨石/密林擋、
  /// 平坦的水池/泥沼/荊棘不擋；玩家建築也不遮擋（狙擊塔規則）。
  /// 沿線每半格取樣一次，查該格環境是否遮擋視線。
  bool terrainBlocksLine(Vector2 from, Vector2 to) {
    final dist = from.distanceTo(to);
    if (dist <= 0) return false;
    final steps = (dist / (board.hexagonRadius * 0.5)).ceil().clamp(1, 400);
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final bp = board.pointToBoardPoint(Offset(
        from.x + (to.x - from.x) * t,
        from.y + (to.y - from.y) * t,
      ));
      final env = environment[bp];
      if (env != null && env.blocksSight) return true;
    }
    return false;
  }

  /// 沿 [from] 往 [dirUnit] 的射線走 [maxLen]，回傳實際終點：
  /// [ignoreTerrain] 為 false 時，撞到遮擋視線的高聳地形（blocksSight）
  /// 就在該處截斷（狙擊塔彈道用）；水池等平坦地形不截斷。
  Vector2 rayEnd(Vector2 from, Vector2 dirUnit, double maxLen,
      {bool ignoreTerrain = false}) {
    final stepLen = board.hexagonRadius * 0.5;
    final steps = (maxLen / stepLen).ceil().clamp(1, 400);
    var last = from.clone();
    for (var i = 1; i <= steps; i++) {
      final p = from + dirUnit * (stepLen * i.toDouble()).clamp(0, maxLen);
      if (!ignoreTerrain) {
        final env = environment[board.pointToBoardPoint(_toOffset(p))];
        if (env != null && env.blocksSight) return last;
      }
      last = p;
    }
    return last;
  }

  /// 起動時把塔的貼地模糊陰影烘成一張共用小圖（做一次）。形狀＝用 iso 地面基向量
  /// 掃出的橢圓（與舊 _renderShadow 同參數），高斯只在此模糊一次；之後各塔以
  /// drawImageRect 貼此圖（見 TowerComponent._renderShadow）。
  void _bakeTowerShadow() {
    final ax = iso.axisX;
    final ay = iso.axisY;
    final r = board.hexagonRadius * 0.52;
    const sigma = 3.0;
    final pad = (sigma * 3).ceil() + 2; // 模糊外擴留白，避免邊緣被裁
    // 橢圓在螢幕上相對塔腳的半寬/半高（對稱 → 塔腳＝影像中心）。
    final halfX = (ax.x.abs() + ay.x.abs()) * r;
    final halfY = (ax.y.abs() + ay.y.abs()) * r;
    final w = (halfX * 2).ceil() + pad * 2;
    final h = (halfY * 2).ceil() + pad * 2;
    final anchor = Offset(w / 2, h / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final path = Path();
    for (var i = 0; i <= 24; i++) {
      final a = i / 24 * 2 * pi;
      final d = ax * (r * cos(a)) + ay * (r * sin(a));
      final p = Offset(anchor.dx + d.x, anchor.dy + d.y);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x40000000) // 黑 25%
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, sigma),
    );
    towerShadowImage = recorder.endRecording().toImageSync(w, h);
    towerShadowAnchor = anchor;
  }

  // ── 尋路 / 放置 ──────────────────────────────────────────
  bool isPointCanMove(BoardPoint point) =>
      board.validateBoardPoint(point) &&
      !towers.containsKey(point) &&
      !(environment[point]?.blocks ?? false); // 擋路型天然環境

  void recomputeGuide() {
    guide = recalculate(targetLocation, isPointCanMove);
    route = _computeRoute();
  }

  List<BoardPoint> _computeRoute() {
    final path = <BoardPoint>[spawnLocation];
    var cur = spawnLocation;
    var guard = 0;
    while (cur != targetLocation && guard++ < 1000) {
      final dir = guide[cur];
      if (dir == null) break;
      cur = cur.getNeighbor(dir);
      path.add(cur);
    }
    return path;
  }

  /// 開局隨機佈置天然環境（未指定 [count] → 每場隨機 5~10 個）；擋路型會確保
  /// 「放下去仍有路可通」→ 不封死路線。
  void generateEnvironment({int? count}) {
    final rng = Random();
    final n = count ?? (5 + rng.nextInt(6)); // 5..10
    var placed = 0, tries = 0;
    while (placed < n && tries < 600) {
      tries++;
      final type = EnvType.values[rng.nextInt(EnvType.values.length)];
      final cell = BoardPoint(
        rng.nextInt(boardRadius * 2 + 1) - boardRadius,
        rng.nextInt(boardRadius * 2 + 1) - boardRadius,
      );
      if (!board.validateBoardPoint(cell)) continue;
      if (cell == spawnLocation || cell == targetLocation) continue;
      if (environment.containsKey(cell)) continue;
      // 擋路型：放下去(含既有擋路環境)仍要有路 → 不封死。
      if (type.blocks &&
          hasPathBetween(spawnLocation, targetLocation, isPointCanMove,
                  {cell}) ==
              null) {
        continue;
      }
      environment[cell] = type;
      world.add(EnvComponent(type, cell));
      placed++;
    }
    recomputeGuide();
  }

  /// 敵人所在格的天然環境減速係數（1＝不減速；泥沼會變慢）。
  double envSlowAt(BoardPoint cell) =>
      environment[cell] == EnvType.mud ? 0.6 : 1.0;

  /// 敵人所在格的天然環境每秒傷害（0＝無；荊棘會持續扣血）。
  double envDpsAt(BoardPoint cell) =>
      environment[cell] == EnvType.thorns ? 8.0 : 0.0;

  /// 在螢幕座標 [pos] 播放一次性塵土特效（敵人出場用）。
  void spawnDust(Vector2 pos) {
    final sz = board.hexagonRadius * 1.5 * iso.scaleX;
    world.add(
      SpriteAnimationComponent(
        animation: dustAnim,
        anchor: Anchor.center,
        position: pos,
        size: Vector2.all(sz),
        removeOnFinish: true,
        priority: pos.y.round() - 2, // 畫在敵人之後(下)，敵人像從塵土中冒出
      )..paint.filterQuality = FilterQuality.none,
    );
  }

  bool hasEnemyOn(BoardPoint point) => enemies.any(
        (e) => e.currentLocation == point || e.goalLocation == point,
      );

  /// 該格是否已有任何建築（塔 / 障礙 / 陷阱），一格只能蓋一個。
  bool hasBuildingAt(BoardPoint point) =>
      towers.containsKey(point) || traps.containsKey(point);

  bool isPlaceable(BoardPoint point) {
    if (hasBuildingAt(point)) return false;
    if (environment.containsKey(point)) return false; // 天然環境格不可建塔
    if (hasEnemyOn(point)) return false;
    if (point == spawnLocation || point == targetLocation) return false;
    final path =
        hasPathBetween(spawnLocation, targetLocation, isPointCanMove, {point});
    return path != null;
  }

  /// 陷阱放置：可蓋在路徑上 → 不做擋路檢查、之後也不重算 flow field。
  bool isTrapPlaceable(BoardPoint point) {
    if (!board.validateBoardPoint(point)) return false;
    if (hasBuildingAt(point)) return false;
    if (environment.containsKey(point)) return false; // 天然環境格不可放陷阱
    if (point == spawnLocation || point == targetLocation) return false;
    return true;
  }

  bool isAffordable(TowerType type) {
    if (type == TowerType.obstacle) return freeObstacle.value > 0;
    return coin.value >= statsOf(type).cost;
  }

  bool tryPlaceAt(BoardPoint point) {
    final type = selecting.value;
    if (type == null) return false;

    if (!cheat.value && !isAffordable(type)) {
      GameAudio.ui('error', volume: 0.6);
      showMessage('We need more gold!');
      return false;
    }

    // 陷阱：蓋在地面、不影響尋路（不進 towers、不重算 flow field）。
    if (isTrapType(type)) {
      if (!isTrapPlaceable(point)) return false;
      final trap = buildTrap(type, point);
      traps[point] = trap;
      world.add(trap);
      coin.value -= statsOf(type).cost;
      GameAudio.ui('drop', volume: 0.8);
      return true;
    }

    if (!isPlaceable(point)) return false;

    final tower = buildTower(type, point);
    towers[point] = tower;
    world.add(tower);
    recomputeGuide();
    refreshMultishotBuffs(); // 新塔/多重箭可能改變鄰塔增益

    if (type == TowerType.obstacle) {
      freeObstacle.value -= 1;
    } else {
      coin.value -= statsOf(type).cost;
    }
    GameAudio.ui('drop', volume: 0.8);
    return true;
  }

  /// 拆除某格的建築：移除元件、退回部分資源、重算路線。
  bool demolishAt(BoardPoint point) {
    // 陷阱：不影響尋路，退回 75% 後直接移除（不需重算）。
    final trap = traps.remove(point);
    if (trap != null) {
      trap.removeFromParent();
      if (inspecting.value == point) inspecting.value = null;
      final refund = (statsOf(trap.type).cost * 0.75).floor();
      coin.value += refund;
      GameAudio.ui('demolish', volume: 0.7);
      showMessage('已拆除陷阱，退回 $refund 金幣');
      return true;
    }

    final tower = towers.remove(point);
    if (tower == null) return false;
    tower.removeFromParent();
    recomputeGuide();
    refreshMultishotBuffs(); // 拆掉多重箭/鄰塔可能改變增益
    if (inspecting.value == point) inspecting.value = null;

    GameAudio.ui('demolish', volume: 0.7);
    if (tower.type == TowerType.obstacle) {
      // 障礙物拆除不退回額度。
      showMessage('已拆除障礙物');
    } else {
      // 退回 75% ×（基礎費 + 已投入的升級費）。
      final refund =
          ((statsOf(tower.type).cost + tower.spentOnUpgrades) * 0.75).floor();
      coin.value += refund;
      showMessage('已拆除，退回 $refund 金幣');
    }
    return true;
  }

  /// 清除天然環境的費用。
  static const int envClearCost = 40;

  /// 該格可否查看資訊：已蓋建築 / 陷阱 / 天然環境、主堡(終點)、敵人出生點。
  bool isInspectable(BoardPoint point) =>
      towers.containsKey(point) ||
      traps.containsKey(point) ||
      environment.containsKey(point) ||
      point == targetLocation ||
      point == spawnLocation;

  /// 花費金幣清除某格天然環境（擋路型清掉後路線會開通、該格變可建造）。
  bool clearEnvironmentAt(BoardPoint point) {
    if (!environment.containsKey(point)) return false;
    if (!cheat.value && coin.value < envClearCost) {
      GameAudio.ui('error', volume: 0.6);
      showMessage('金幣不足');
      return false;
    }
    if (!cheat.value) coin.value -= envClearCost;
    environment.remove(point);
    world.children
        .whereType<EnvComponent>()
        .where((c) => c.location == point)
        .toList()
        .forEach((c) => c.removeFromParent());
    recomputeGuide(); // 擋路型清除後重算路線
    if (inspecting.value == point) inspecting.value = null;
    showMessage('已清除天然環境，退還該格可建造');
    return true;
  }

  /// 點選某格：可查看→顯示資訊（並取消正在選的塔）；否則→關閉資訊面板。
  void inspectAt(BoardPoint point) {
    if (!isInspectable(point)) {
      inspecting.value = null;
      return;
    }
    selecting.value = null;
    inspecting.value = point;
  }

  TowerType? typeAt(BoardPoint point) =>
      towers[point]?.type ?? traps[point]?.type;

  /// 該格是否為滾木塔（供瀏覽面板顯示方向控制）。
  bool isLogTower(BoardPoint point) => towers[point] is LogTowerComponent;

  /// 旋轉滾木塔的發射方向（delta = ±1）。
  void rotateLog(BoardPoint point, int delta) {
    final t = towers[point];
    if (t is LogTowerComponent) t.rotate(delta);
  }

  /// 該格是否相鄰(6 格)有「多重箭」支援塔（來源真值，只在重算時用）。
  bool multishotAt(BoardPoint point) {
    for (final n in point.getNeighbors()) {
      if (towers[n] is MultishotTowerComponent) return true;
    }
    return false;
  }

  /// 重算每座塔的多重箭快取旗標。只在建造/拆除塔時呼叫（稀有事件），
  /// 各塔平時只讀 `multishotBuffed`，不必每幀掃鄰格。
  void refreshMultishotBuffs() {
    for (final entry in towers.entries) {
      entry.value.multishotBuffed = multishotAt(entry.key);
    }
  }

  int towerLevel(BoardPoint point) => towers[point]?.level ?? 1;

  /// 該塔目前可選的升級節點：Lv1 → 兩個分支；Lv2 → 所選分支底下兩個葉；Lv3 → 空。
  List<TowerUpgradeNode> upgradeOptions(BoardPoint point) {
    final t = towers[point];
    if (t == null) return const [];
    if (t.chosen.isEmpty) return kTowerUpgradeTree[t.type] ?? const [];
    if (t.chosen.length == 1) return t.chosen.last.children;
    return const [];
  }

  /// 升級該塔：選定某個升級節點（扣金幣、套用該節點的 mods）。
  bool upgradeTower(BoardPoint point, TowerUpgradeNode node) {
    final t = towers[point];
    if (t == null) return false;
    if (!upgradeOptions(point).contains(node)) return false; // 只能選當前可選項
    if (!cheat.value && coin.value < node.cost) {
      GameAudio.ui('error', volume: 0.6);
      showMessage('金幣不足');
      return false;
    }
    if (!cheat.value) coin.value -= node.cost;
    t.applyUpgrade(node);
    t.spentOnUpgrades += node.cost;
    GameAudio.ui('confirm', volume: 0.7);
    towerChanged.value++; // 讓資訊面板更新
    return true;
  }

  /// 讓場上的陷阱對「敵人的路線位置 [pos]」施加位置力場（如渦流吸引），就地修改
  /// [pos]。純顯示用、不影響尋路進度。[seed]（敵人身分）讓散布角度穩定。
  void applyTrapPull(Vector2 pos, int seed) {
    for (final t in traps.values) {
      t.pullPosition(pos, seed);
    }
  }

  /// 在路線位置 [pos] 處，場上陷阱對敵人路線進度的減速係數（多個取乘積）。
  /// 1＝不減速；渦流會讓被吸引的敵人真的放慢進度，避免脫離時暴衝。
  double trapSlowFactor(Vector2 pos) {
    var f = 1.0;
    for (final t in traps.values) {
      f *= t.slowFactor(pos);
    }
    return f;
  }

  void selectTower(TowerType? type) {
    selecting.value = type;
    inspecting.value = null;
  }

  void cancelSelection() {
    selecting.value = null;
    inspecting.value = null;
    aimingSkill.value = null;
  }

  // ── 狙擊塔主動技瞄準模式 ──────────────────────────────────
  /// 非 null＝正在為該格的狙擊塔選擇射擊方向：棋盤點擊改為「朝該點方向開火」，
  /// BoardComponent 會畫瞄準預覽線。
  final ValueNotifier<BoardPoint?> aimingSkill = ValueNotifier(null);

  /// 進入瞄準模式（資訊面板的技能鈕呼叫）。技能未解鎖或 CD 中不進入。
  void startSkillAim(BoardPoint point) {
    final t = towers[point];
    if (t is! SniperTowerComponent || !t.skillReady) return;
    aimingSkill.value = point;
    showMessage('點擊地圖任一點，朝該方向狙擊');
  }

  /// 瞄準模式下點擊棋盤：朝該「螢幕點」的方向施放主動技，並退出瞄準模式。
  bool castSkillToward(Vector2 screen) {
    final bp = aimingSkill.value;
    aimingSkill.value = null;
    final t = bp == null ? null : towers[bp];
    if (t is! SniperTowerComponent) return false;
    return t.castSkillAt(iso.screenToLogical(screen));
  }
  void toggleCheat() => cheat.value = !cheat.value;

  // ── 敵人登記 ─────────────────────────────────────────────
  /// 已排進 world 但尚未 mount 的敵人數。敵人 world.add 後要下一幀才 mount 進
  /// [enemies]，若「最後一隻在場敵人死亡」與「佇列還有敵人」同幀發生，完成判定
  /// 只看 enemies.isEmpty 會提前成立 → 波次被誤判完成、之後 startGame 又因
  /// enemies 非空永遠拒開 → 卡死。所有敵人生成一律走 [spawnEnemy] 維護此計數。
  int _pendingEnemyMounts = 0;

  /// 生成敵人的唯一入口：計數 + 排進 world（mount 時歸帳）。
  void spawnEnemy(EnemyComponent e) {
    _pendingEnemyMounts++;
    world.add(e);
  }

  void registerEnemy(EnemyComponent e) {
    enemies.add(e);
    if (_pendingEnemyMounts > 0) _pendingEnemyMounts--;
  }

  void unregisterEnemy(EnemyComponent e) => enemies.remove(e);

  // ── 範圍查詢（全部用邏輯座標）─────────────────────────────
  Iterable<EnemyComponent> enemiesInRange(
      Vector2 logicalCenter, double rangeInHex) {
    final r = board.hexagonRadius * rangeInHex;
    return enemies.where(
      (e) => !e.isDead && logicalCenter.distanceTo(e.logicalPos) <= r,
    );
  }

  EnemyComponent? nearestEnemy(Vector2 logicalCenter, double rangeInHex) {
    EnemyComponent? best;
    var bestDistance = double.infinity;
    for (final e in enemiesInRange(logicalCenter, rangeInHex)) {
      final d = logicalCenter.distanceTo(e.logicalPos);
      if (d < bestDistance) {
        bestDistance = d;
        best = e;
      }
    }
    return best;
  }

  bool isInsideRange(Vector2 logicalDiff, double rangeInHex) =>
      logicalDiff.length <= board.hexagonRadius * rangeInHex;

  // ── 經濟 / 勝負 ──────────────────────────────────────────
  void onEnemyKilled(EnemyComponent e) {
    coin.value += e.kind.reward;
    // 死亡處爆金幣特效（賞金越高噴越多）+ 上升的亮十字閃光。
    final pos = e.position + Vector2(0, -board.hexagonRadius * iso.scaleX * 0.5);
    final n = (4 + e.kind.reward ~/ 4).clamp(4, 14);
    world
      ..add(coinBurst(pos, iso.scaleX, count: n))
      ..add(coinSparkle(pos, iso.scaleX));
    GameAudio.world('death', e.position, volume: 0.5, throttleMs: 60);
    GameAudio.ui('coin', volume: 0.45, throttleMs: 110);
  }

  void onEnemyLeaked(EnemyComponent e) {
    GameAudio.ui('leak', volume: 0.8, throttleMs: 250);
    heart.value -= e.kind.leakDamage;
    if (heart.value <= 0) triggerGameOver();
  }

  void startGame() {
    if (gameOver.value || gameWon.value) return;
    if (_spawner != null || enemies.isNotEmpty) return;
    if (!endless.value && waveNumber >= totalWaves) return;

    waveNumber++;
    wave.value = waveNumber;
    waveRunning.value = true;
    GameAudio.bgmBattle(); // 開打 → crossfade 到戰鬥曲（冪等，之後波次無動作）
    _spawner = WaveSpawnerComponent(
      schedule: buildWaveSchedule(waveNumber),
      base: enemyStatusForWave(waveNumber),
    );
    world.add(_spawner!);
  }

  final Random _spawnRng = Random();

  /// 該波的敵人組成（權重填充版）：
  /// - 只納入「已解鎖（unlockWave ≤ wave）」的種類。
  /// - 該波「剛解鎖」的種類各固定給幾隻當介紹。
  /// - 其餘名額依權重隨機填充，最後打散避免同種擠在一起。
  List<EnemyKind> buildWaveComposition(int wave) {
    final unlocked =
        EnemyKind.all.where((k) => k.unlockWave <= wave).toList();
    final total = 12 + (wave * 0.6).round();
    final result = <EnemyKind>[];

    // 剛解鎖的種類：這波至少各給 3 隻試水溫。
    for (final k in unlocked.where((k) => k.unlockWave == wave)) {
      result.addAll(List.filled(3, k));
    }

    // 其餘依權重填充。
    final weightSum = unlocked.fold<double>(0, (s, k) => s + k.weight);
    while (result.length < total) {
      var r = _spawnRng.nextDouble() * weightSum;
      var pick = unlocked.first;
      for (final k in unlocked) {
        r -= k.weight;
        if (r <= 0) {
          pick = k;
          break;
        }
      }
      result.add(pick);
    }

    result.shuffle(_spawnRng);
    return result;
  }

  /// Boss 波（每 5 波）。
  static const Set<int> bossWaves = {10, 15, 20, 25};

  /// 讀/寫無盡模式最佳紀錄（測試等無外掛環境安靜略過）。
  Future<void> _loadBestEndless() async {
    try {
      final p = await SharedPreferences.getInstance();
      bestEndless.value = p.getInt('bestEndlessWave') ?? 0;
    } catch (_) {/* no-op */}
  }

  Future<void> _saveBestEndless(int waves) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('bestEndlessWave', waves);
    } catch (_) {/* no-op */}
  }

  /// 該波是否為 Boss 波：闖關看固定清單；無盡第 10 波起每 5 波一次。
  bool isBossWave(int wave) =>
      endless.value ? wave >= 10 && wave % 5 == 0 : bossWaves.contains(wave);

  /// 招牌小隊（combo）：在指定波插入「擠在一起出現」的互補小隊。
  /// 目前只用已實作的種類；補師/護盾/分裂/再生等敵人做出來後再補更多波。
  static final Map<int, List<EnemyKind>> _squads = {
    7: [EnemyKind.brute, EnemyKind.brute, EnemyKind.scout, EnemyKind.scout, EnemyKind.scout],
    12: [EnemyKind.brute, EnemyKind.brute, EnemyKind.scout, EnemyKind.scout, EnemyKind.scout],
    14: [
      EnemyKind.swarm, EnemyKind.swarm, EnemyKind.swarm, EnemyKind.swarm,
      EnemyKind.swarm, EnemyKind.swarm, EnemyKind.swarm, EnemyKind.swarm,
    ],
    17: [
      EnemyKind.brute, EnemyKind.brute, EnemyKind.brute,
      EnemyKind.scout, EnemyKind.scout, EnemyKind.scout, EnemyKind.scout,
    ],
  };

  /// 各波「隨機組成」快取：波次預告與實際生成共用同一份（只骰一次，
  /// 否則預告顯示的跟實際開波的會是兩次不同的隨機結果）。
  final Map<int, List<EnemyKind>> _compCache = {};

  List<EnemyKind> _cachedComposition(int wave) =>
      _compCache.putIfAbsent(wave, () => buildWaveComposition(wave));

  /// 第 [wave] 波玩家實際會遇到的完整敵人清單（含招牌小隊 / Boss 波的 Boss），
  /// 給「下一波預告」UI 用；與 buildWaveSchedule 用同一份快取組成。
  List<EnemyKind> waveLineup(int wave) {
    if (isBossWave(wave)) {
      return [..._cachedComposition(wave).take(10), EnemyKind.juggernaut];
    }
    return [..._cachedComposition(wave), ...?_squads[wave]];
  }

  /// 該波完整生成序列：Boss 波 → 護衛+Boss；一般波 → 權重填充（可能插入招牌小隊）。
  List<SpawnTick> buildWaveSchedule(int wave) {
    if (isBossWave(wave)) return _bossSchedule(wave);

    final ticks = <SpawnTick>[
      for (final k in _cachedComposition(wave)) SpawnTick(k, 1.0),
    ];
    if (ticks.isNotEmpty) ticks[0] = SpawnTick(ticks.first.kind, 0.5);

    final squad = _squads[wave];
    if (squad != null) {
      final squadTicks = <SpawnTick>[
        for (var i = 0; i < squad.length; i++)
          SpawnTick(squad[i], i == 0 ? 1.2 : 0.25), // 首隻正常間隔、其餘擠一起
      ];
      ticks.insertAll((ticks.length / 2).floor(), squadTicks);
    }
    return ticks;
  }

  /// 目前「已解鎖（出現過）」的敵人種類，給敵人圖鑑 UI 用。
  List<EnemyKind> unlockedKinds() {
    final w = waveNumber < 1 ? 1 : waveNumber;
    return [
      for (final k in EnemyKind.all)
        if (k.unlockWave <= w) k,
      if (w >= bossWaves.first) EnemyKind.juggernaut,
    ];
  }

  /// Boss 波序列：幾隻護衛 → Boss 登場 → 其餘護衛。
  List<SpawnTick> _bossSchedule(int wave) {
    final escort = _cachedComposition(wave).take(10).toList();
    final ticks = <SpawnTick>[];
    for (var i = 0; i < escort.length; i++) {
      ticks.add(SpawnTick(escort[i], i == 0 ? 0.5 : 0.8));
      if (i == 3) ticks.add(SpawnTick(EnemyKind.juggernaut, 1.6)); // 第 4 隻後 Boss 登場
    }
    return ticks;
  }

  EnemyStatus enemyStatusForWave(int wave) {
    var hp = (100.0 + (wave - 1) * 40);
    // 原始移速公式（線性成長；全怪移速 -15%）。
    var speed = (1.5 + (wave - 1) * 0.05) * 0.85;
    if (wave > totalWaves) {
      // 無盡 25 波後：血量每波 ×1.08 複利 → 難度持續攀升、終有一倒。
      hp *= pow(1.08, wave - totalWaves);
      // 移速凍結在第 25 波的值（後期不再變快），原本要加的移速以
      // 「威力等價」1:1 轉成血量：強度 ≈ 血量×移速（越快輸出窗口越短），
      // 故 hp ×= 原速度/凍結速度。
      final speedCap = (1.5 + (totalWaves - 1) * 0.05) * 0.85;
      hp *= speed / speedCap;
      speed = speedCap;
    }
    return EnemyStatus(totalHp: hp, currentHp: hp, speed: speed);
  }

  @override
  void update(double dt) {
    _advanceFling(dt); // 甩動慣性滑行（UI 手感，用真實 dt、每幀一次）
    // 3D 音訊 listener 跟著相機（拉遠變小聲、偏左的音源偏左耳）。
    GameAudio.updateListener(camera.viewfinder.position, camera.viewfinder.zoom);
    // demoSpeed×gameSpeed 個子步，每步都用正常 dt（保留細粒度、只是播放變快）。
    final steps = demoSpeed * gameSpeed.value;
    for (var step = 0; step < steps; step++) {
      super.update(dt);
      final spawner = _spawner;
      if (spawner != null &&
          spawner.isDone &&
          enemies.isEmpty &&
          _pendingEnemyMounts == 0) {
        spawner.removeFromParent();
        _spawner = null;
        _onWaveCompleted();
      }
      if (gameOver.value || gameWon.value) break;
    }
  }

  /// 開始自動演示：清空重來 → 掛上自動玩家 → 加速播放。
  void startAutoDemo() {
    resetForDemo();
    _autoPlayer ??= AutoPlayerComponent();
    if (!_autoPlayer!.isMounted) add(_autoPlayer!);
    demoSpeed = 4;
    demoRunning.value = true;
    resumeEngine();
  }

  /// 停止自動演示（保留目前盤面，恢復正常速度、交還玩家操作）。
  void stopAutoDemo() {
    _autoPlayer?.removeFromParent();
    _autoPlayer = null;
    demoSpeed = 1;
    demoRunning.value = false;
  }

  /// 把整局重設回開局狀態（給演示用，不重建 game）。
  void resetForDemo() {
    endless.value = false; // 自動演示固定跑闖關模式
    for (final t in towers.values) {
      t.removeFromParent();
    }
    towers.clear();
    for (final t in traps.values) {
      t.removeFromParent();
    }
    traps.clear();
    for (final e in [...enemies]) {
      e.removeFromParent();
    }
    enemies.clear();
    _spawner?.removeFromParent();
    _spawner = null;

    coin.value = 150;
    heart.value = 20;
    freeObstacle.value = 3;
    waveNumber = 0;
    completedWaves = 0;
    _pendingEnemyMounts = 0;
    _compCache.clear(); // 波次組成快取（預告用）重骰
    wave.value = 0;
    waveRunning.value = false;
    gameOver.value = false;
    gameWon.value = false;
    inspecting.value = null;
    selecting.value = null;
    recomputeGuide();
    resumeEngine();
  }

  /// 風刃塔相鄰密林時，每波產出的林木金幣。
  static const int kWoodsIncome = 8;

  void _onWaveCompleted() {
    completedWaves++;
    waveRunning.value = false;
    freeObstacle.value += 1; // 每完成一波送一個障礙物
    _grantWoodsIncome(); // 風刃塔 × 密林：每波產小量金幣
    if (endless.value) {
      // 無盡：沒有勝利條件；每波結束就更新最佳紀錄（避免關頁面漏存）。
      if (completedWaves > bestEndless.value) {
        bestEndless.value = completedWaves;
        newEndlessRecord = true;
        _saveBestEndless(completedWaves);
      }
      return;
    }
    if (completedWaves >= totalWaves) {
      gameWon.value = true;
      GameAudio.gameEnd(won: true);
      pauseEngine();
    }
  }

  /// 風刃塔每有一片「相鄰密林(woods)」，每波就產出 [kWoodsIncome] 金幣
  /// （相鄰兩片密林＝2×，以此類推）。
  void _grantWoodsIncome() {
    var gold = 0;
    for (final entry in towers.entries) {
      if (entry.value is! AirBladeTowerComponent) continue;
      var g = 0;
      for (final n in entry.key.getNeighbors()) {
        if (environment[n] == EnvType.woods) {
          g += kWoodsIncome; // 每片相鄰密林各算一次
        }
      }
      if (g == 0) continue;
      gold += g;
      // 有收穫的風刃塔頂爆金幣（與擊殺同款特效，收穫越多噴越多）。
      final pos = entry.value.position +
          Vector2(0, -board.hexagonRadius * iso.scaleX * 0.5);
      final cnt = (4 + g ~/ 4).clamp(4, 14);
      world
        ..add(coinBurst(pos, iso.scaleX, count: cnt))
        ..add(coinSparkle(pos, iso.scaleX));
    }
    if (gold > 0) {
      coin.value += gold;
      // 通知 HUD 顯示「+xx 從密林」浮動提示（序號遞增 → 金額相同也會重播）。
      woodsIncome.value = ((woodsIncome.value?.$1 ?? 0) + 1, gold);
    }
  }

  void triggerGameOver() {
    if (gameOver.value) return;
    gameOver.value = true;
    GameAudio.gameEnd(won: false);
    pauseEngine();
  }

  void showMessage(String message) => showTopMessage(message);

  @override
  void onRemove() {
    coin.dispose();
    heart.dispose();
    freeObstacle.dispose();
    cheat.dispose();
    selecting.dispose();
    inspecting.dispose();
    inspectingEnemy.dispose();
    towerChanged.dispose();
    wave.dispose();
    waveRunning.dispose();
    gameOver.dispose();
    gameWon.dispose();
    woodsIncome.dispose();
    gameSpeed.dispose();
    endless.dispose();
    bestEndless.dispose();
    towerShadowImage.dispose();
    super.onRemove();
  }
}

/// 相機單軸滑行狀態：[sim] 起初是摩擦（FrictionSimulation），撞到邊界後換成
/// 「錨在邊界上」的彈簧（SpringSimulation）回彈；[t] 是目前 sim 自身的經過秒數
/// （換 sim 時歸零）。[bouncing]＝已切換成彈簧（每軸只回彈一次、不反覆）。
class _CameraFling {
  _CameraFling(this.sim);
  Simulation sim;
  double t = 0;
  bool bouncing = false;
}

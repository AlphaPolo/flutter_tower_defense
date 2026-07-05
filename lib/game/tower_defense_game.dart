import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../screens/my_app.dart' show showTopMessage;
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

  // ── 自動演示 ──────────────────────────────────────────────
  final ValueNotifier<bool> demoRunning = ValueNotifier(false);
  AutoPlayerComponent? _autoPlayer;
  int demoSpeed = 1; // 演示時把每幀模擬步數加倍 → 加速播放（每步仍用正常 dt）

  @override
  Future<void> onLoad() async {
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
      // 多重箭：暫用佔位 sprite（實際外觀由元件自行繪製）。
      TowerType.multishot: obstacleSprites.first,
    };
    logSheet = await isoImages.load('log_roll.png');
    explosionSheet = await isoImages.load('explosion.png');
    try {
      waterProgram =
          await ui.FragmentProgram.fromAsset('assets/shaders/water.frag');
    } catch (_) {
      waterProgram = null; // shader 不可用時退回平面水池
    }
    for (final k in [...EnemyKind.all, EnemyKind.juggernaut]) {
      final sheet = k.sheet;
      if (sheet != null) enemySheets[k.id] = await isoImages.load(sheet);
    }

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

  void _fitCamera() {
    final s = iso.imageSize;
    camera.viewfinder.position = Vector2(s.x / 2, s.y / 2);
    camera.viewfinder.zoom = min(size.x / s.x, size.y / s.y) * 0.95;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    final next = camera.viewfinder.zoom * (delta > 0 ? 0.9 : 1.1);
    camera.viewfinder.zoom = next.clamp(0.1, 3.0);
  }

  // ── 觸控：雙指縮放、單指平移 ──────────────────────────────
  double _startZoom = 1;

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (info.pointerCount > 1) {
      // 雙指 → 縮放（用整體 pinch 距離，往外張放大、捏合縮小，與方向無關）
      camera.viewfinder.zoom = (_startZoom * info.raw.scale).clamp(0.1, 3.0);
    } else {
      // 單指 → 平移（螢幕位移換算成世界位移）
      camera.viewfinder.position +=
          -info.delta.global / camera.viewfinder.zoom;
    }
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
      showMessage('已拆除陷阱，退回 $refund 金幣');
      return true;
    }

    final tower = towers.remove(point);
    if (tower == null) return false;
    tower.removeFromParent();
    recomputeGuide();
    refreshMultishotBuffs(); // 拆掉多重箭/鄰塔可能改變增益
    if (inspecting.value == point) inspecting.value = null;

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
      showMessage('金幣不足');
      return false;
    }
    if (!cheat.value) coin.value -= node.cost;
    t.applyUpgrade(node);
    t.spentOnUpgrades += node.cost;
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
  }
  void toggleCheat() => cheat.value = !cheat.value;

  // ── 敵人登記 ─────────────────────────────────────────────
  void registerEnemy(EnemyComponent e) => enemies.add(e);
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
  void onEnemyKilled(EnemyComponent e) => coin.value += e.kind.reward;

  void onEnemyLeaked(EnemyComponent e) {
    heart.value -= e.kind.leakDamage;
    if (heart.value <= 0) triggerGameOver();
  }

  void startGame() {
    if (gameOver.value || gameWon.value) return;
    if (_spawner != null || enemies.isNotEmpty) return;
    if (waveNumber >= totalWaves) return;

    waveNumber++;
    wave.value = waveNumber;
    waveRunning.value = true;
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

  /// 該波完整生成序列：Boss 波 → 護衛+Boss；一般波 → 權重填充（可能插入招牌小隊）。
  List<SpawnTick> buildWaveSchedule(int wave) {
    if (bossWaves.contains(wave)) return _bossSchedule(wave);

    final ticks = <SpawnTick>[
      for (final k in buildWaveComposition(wave)) SpawnTick(k, 1.0),
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
    final escort = buildWaveComposition(wave).take(10).toList();
    final ticks = <SpawnTick>[];
    for (var i = 0; i < escort.length; i++) {
      ticks.add(SpawnTick(escort[i], i == 0 ? 0.5 : 0.8));
      if (i == 3) ticks.add(SpawnTick(EnemyKind.juggernaut, 1.6)); // 第 4 隻後 Boss 登場
    }
    return ticks;
  }

  EnemyStatus enemyStatusForWave(int wave) {
    final hp = (100.0 + (wave - 1) * 40) * 0.9; // 全怪血量 -10%
    final speed = (1.5 + (wave - 1) * 0.05) * 0.9; // 全怪移速 -10%
    return EnemyStatus(totalHp: hp, currentHp: hp, speed: speed);
  }

  @override
  void update(double dt) {
    // demoSpeed 個子步，每步都用正常 dt（保留細粒度、只是播放變快）。
    for (var step = 0; step < demoSpeed; step++) {
      super.update(dt);
      final spawner = _spawner;
      if (spawner != null && spawner.isDone && enemies.isEmpty) {
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
    wave.value = 0;
    waveRunning.value = false;
    gameOver.value = false;
    gameWon.value = false;
    inspecting.value = null;
    selecting.value = null;
    recomputeGuide();
    resumeEngine();
  }

  void _onWaveCompleted() {
    completedWaves++;
    waveRunning.value = false;
    freeObstacle.value += 1; // 每完成一波送一個障礙物
    if (completedWaves >= totalWaves) {
      gameWon.value = true;
      pauseEngine();
    }
  }

  void triggerGameOver() {
    if (gameOver.value) return;
    gameOver.value = true;
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
    super.onRemove();
  }
}

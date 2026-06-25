import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../screens/my_app.dart' show scaffoldMessengerKey;
import 'board/hex.dart';
import 'board/pathfinding.dart';
import 'components/board_component.dart';
import 'components/enemy_component.dart';
import 'components/tower/tower_component.dart';
import 'components/tower/tower_factory.dart';
import 'components/wave_spawner.dart';
import 'iso/iso_projection.dart';
import 'tower_type.dart';

/// 整個塔防遊戲的 FlameGame（isometric 版）。
///
/// 遊戲邏輯（移動、射程、瞄準、尋路）全部在「top-down 邏輯座標」進行；
/// [iso] 只在繪製時把邏輯座標投影成 isometric 螢幕座標。棋盤是預先用
/// Blender 渲染好的一張 isometric 圖。
class TowerDefenseGame extends FlameGame with ScrollDetector {
  TowerDefenseGame();

  static const int boardRadius = 5;
  static const double hexRadius = 32;
  static const double hexMargin = 4;

  late final Board board;
  late final IsoProjection iso;
  late final BoardPoint spawnLocation;
  late final BoardPoint targetLocation;

  /// 每個格子要往哪個方向走（從終點往回算的 flow field）。
  Map<BoardPoint, HexagonDirection> guide = {};

  /// 場上的敵人與塔（元件自行在 onMount / onRemove 時登記）。
  final List<EnemyComponent> enemies = [];
  final Map<BoardPoint, TowerComponent> towers = {};

  late final BoardComponent boardComponent;

  // ── isometric 素材 ───────────────────────────────────────
  final Images isoImages = Images(prefix: 'assets/iso/');
  late final Sprite boardSprite;
  late final Map<TowerType, Sprite> towerSprites;

  // ── 波次 ─────────────────────────────────────────────────
  static const int totalWaves = 12;
  int waveNumber = 0;
  int completedWaves = 0;
  WaveSpawnerComponent? _spawner;

  // ── 給 UI overlay 監聽的狀態 ──────────────────────────────
  final ValueNotifier<int> coin = ValueNotifier(150);
  final ValueNotifier<int> heart = ValueNotifier(20);
  final ValueNotifier<int> freeObstacle = ValueNotifier(3);
  final ValueNotifier<bool> cheat = ValueNotifier(false);
  final ValueNotifier<TowerType?> selecting = ValueNotifier(null);
  final ValueNotifier<int> wave = ValueNotifier(0);
  final ValueNotifier<bool> waveRunning = ValueNotifier(false);
  final ValueNotifier<bool> gameOver = ValueNotifier(false);
  final ValueNotifier<bool> gameWon = ValueNotifier(false);

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
    towerSprites = {
      TowerType.flame: await Sprite.load('tower_flame.png', images: isoImages),
      TowerType.freezing:
          await Sprite.load('tower_freezing.png', images: isoImages),
      TowerType.airBlade:
          await Sprite.load('tower_airblade.png', images: isoImages),
      TowerType.thunder:
          await Sprite.load('tower_thunder.png', images: isoImages),
      TowerType.obstacle:
          await Sprite.load('tower_obstacle.png', images: isoImages),
    };

    boardComponent = BoardComponent();
    await world.add(boardComponent);

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
      board.validateBoardPoint(point) && !towers.containsKey(point);

  void recomputeGuide() {
    guide = recalculate(targetLocation, isPointCanMove);
  }

  bool hasEnemyOn(BoardPoint point) => enemies.any(
        (e) => e.currentLocation == point || e.goalLocation == point,
      );

  bool isPlaceable(BoardPoint point) {
    if (towers.containsKey(point)) return false;
    if (hasEnemyOn(point)) return false;
    if (point == spawnLocation || point == targetLocation) return false;
    final path =
        hasPathBetween(spawnLocation, targetLocation, isPointCanMove, {point});
    return path != null;
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
    if (!isPlaceable(point)) return false;

    final tower = buildTower(type, point);
    towers[point] = tower;
    world.add(tower);
    recomputeGuide();

    if (type == TowerType.obstacle) {
      freeObstacle.value -= 1;
    } else {
      coin.value -= statsOf(type).cost;
    }
    return true;
  }

  void selectTower(TowerType? type) => selecting.value = type;
  void cancelSelection() => selecting.value = null;
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
  void onEnemyKilled(EnemyComponent e) => coin.value += 5;

  void onEnemyLeaked(EnemyComponent e) {
    heart.value -= 1;
    if (heart.value <= 0) triggerGameOver();
  }

  void startGame() {
    if (gameOver.value || gameWon.value) return;
    if (_spawner != null || enemies.isNotEmpty) return;
    if (waveNumber >= totalWaves) return;

    waveNumber++;
    wave.value = waveNumber;
    waveRunning.value = true;
    _spawner = WaveSpawnerComponent(status: enemyStatusForWave(waveNumber));
    world.add(_spawner!);
  }

  EnemyStatus enemyStatusForWave(int wave) {
    final hp = 100.0 + (wave - 1) * 40;
    final speed = 1.5 + (wave - 1) * 0.05;
    return EnemyStatus(totalHp: hp, currentHp: hp, speed: speed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final spawner = _spawner;
    if (spawner != null && spawner.isDone && enemies.isEmpty) {
      spawner.removeFromParent();
      _spawner = null;
      _onWaveCompleted();
    }
  }

  void _onWaveCompleted() {
    completedWaves++;
    waveRunning.value = false;
    if (completedWaves % 2 == 0) {
      freeObstacle.value += 1;
    }
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

  void showMessage(String message) {
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void onRemove() {
    coin.dispose();
    heart.dispose();
    freeObstacle.dispose();
    cheat.dispose();
    selecting.dispose();
    wave.dispose();
    waveRunning.dispose();
    gameOver.dispose();
    gameWon.dispose();
    super.onRemove();
  }
}

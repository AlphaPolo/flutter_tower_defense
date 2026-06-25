import 'dart:math';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../screens/my_app.dart' show scaffoldMessengerKey;
import 'board/hex.dart';
import 'board/pathfinding.dart';
import 'components/board_component.dart';
import 'components/enemy_component.dart';
import 'components/tower/tower_component.dart';
import 'components/tower/tower_factory.dart';
import 'components/wave_spawner.dart';
import 'tower_type.dart';

/// 整個塔防遊戲的 FlameGame。
///
/// 取代了舊的 GameManager + 各種 Manager + 自製 game loop：
/// - 遊戲迴圈交給 Flame 的 update(dt)
/// - 敵人 / 塔 / 子彈各自是會自己 update 的 Component
/// - 只保留六角棋盤幾何與 flow-field 尋路
class TowerDefenseGame extends FlameGame with ScrollDetector {
  TowerDefenseGame();

  static const int boardRadius = 5;
  static const double hexRadius = 32;
  static const double hexMargin = 4;

  late final Board board;
  late final BoardPoint spawnLocation;
  late final BoardPoint targetLocation;

  /// 每個格子要往哪個方向走（從終點往回算的 flow field）。
  Map<BoardPoint, HexagonDirection> guide = {};

  /// 場上的敵人與塔（元件自行在 onMount / onRemove 時登記）。
  final List<EnemyComponent> enemies = [];
  final Map<BoardPoint, TowerComponent> towers = {};

  late final BoardComponent boardComponent;

  // ── 波次 ─────────────────────────────────────────────────
  static const int totalWaves = 12;
  int waveNumber = 0; // 已開始到第幾波
  int completedWaves = 0; // 已清完幾波
  WaveSpawnerComponent? _spawner; // 目前進行中的那一波（null 表示沒有）

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
    // 左上為主堡（終點），右下為怪物出生點。
    targetLocation = const BoardPoint(0, -boardRadius);
    spawnLocation = const BoardPoint(0, boardRadius);
    recomputeGuide();

    boardComponent = BoardComponent();
    world.add(boardComponent);

    _fitCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _fitCamera();
  }

  void _fitCamera() {
    final s = board.size;
    camera.viewfinder.position = Vector2(s.width / 2, s.height / 2);
    final zoomX = size.x / s.width;
    final zoomY = size.y / s.height;
    camera.viewfinder.zoom = min(zoomX, zoomY) * 0.85;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    final next = camera.viewfinder.zoom * (delta > 0 ? 0.9 : 1.1);
    camera.viewfinder.zoom = next.clamp(0.2, 3.0);
  }

  // ── 座標換算 ──────────────────────────────────────────────
  Vector2 boardToWorld(BoardPoint bp) {
    final o = board.boardPointToOffset(bp);
    // 棋盤六角格的視覺中心比 boardPointToPoint 高了 hexMargin（格子頂點從
    // -hexagonRadius 起算），把實體往上補回來才會落在格子正中央。
    return Vector2(o.dx, o.dy - hexMargin);
  }

  BoardPoint? worldToBoard(Vector2 v) =>
      board.pointToBoardPoint(Offset(v.x, v.y));

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

    // 蓋下去之後仍要能從出生點走到終點。
    final path =
        hasPathBetween(spawnLocation, targetLocation, isPointCanMove, {point});
    return path != null;
  }

  bool isAffordable(TowerType type) {
    if (type == TowerType.obstacle) return freeObstacle.value > 0;
    return coin.value >= statsOf(type).cost;
  }

  /// 嘗試在 [point] 蓋下目前選取的塔。回傳是否成功。
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

    // 扣款 / 扣障礙物數量（與舊版一致，作弊模式只略過可負擔檢查）。
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

  // ── 敵人 / 塔 登記（由元件自行呼叫）──────────────────────
  void registerEnemy(EnemyComponent e) => enemies.add(e);
  void unregisterEnemy(EnemyComponent e) => enemies.remove(e);

  // ── 範圍查詢（給塔 / 子彈瞄準用）─────────────────────────
  Iterable<EnemyComponent> enemiesInRange(Vector2 center, double rangeInHex) {
    final r = board.hexagonRadius * rangeInHex;
    return enemies.where(
      (e) => !e.isDead && center.distanceTo(e.position) <= r,
    );
  }

  EnemyComponent? nearestEnemy(Vector2 center, double rangeInHex) {
    EnemyComponent? best;
    var bestDistance = double.infinity;
    for (final e in enemiesInRange(center, rangeInHex)) {
      final d = center.distanceTo(e.position);
      if (d < bestDistance) {
        bestDistance = d;
        best = e;
      }
    }
    return best;
  }

  bool isInsideRange(Vector2 diff, double rangeInHex) =>
      diff.length <= board.hexagonRadius * rangeInHex;

  // ── 經濟 / 勝負 ──────────────────────────────────────────
  void onEnemyKilled(EnemyComponent e) {
    coin.value += 5;
  }

  void onEnemyLeaked(EnemyComponent e) {
    heart.value -= 1;
    if (heart.value <= 0) triggerGameOver();
  }

  /// 按下 ▶：開始下一波。要等前一波清空、且還沒到第 12 波。
  void startGame() {
    if (gameOver.value || gameWon.value) return;
    if (_spawner != null || enemies.isNotEmpty) return; // 前一波還沒結束
    if (waveNumber >= totalWaves) return; // 已是最後一波

    waveNumber++;
    wave.value = waveNumber;
    waveRunning.value = true;
    _spawner = WaveSpawnerComponent(status: enemyStatusForWave(waveNumber));
    world.add(_spawner!);
  }

  /// 每一波敵人會變強：血量與速度隨波數提升。
  EnemyStatus enemyStatusForWave(int wave) {
    final hp = 100.0 + (wave - 1) * 40;
    final speed = 1.5 + (wave - 1) * 0.05;
    return EnemyStatus(totalHp: hp, currentHp: hp, speed: speed);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final spawner = _spawner;
    // 該波生完且場上沒有敵人 → 過關。
    if (spawner != null && spawner.isDone && enemies.isEmpty) {
      spawner.removeFromParent();
      _spawner = null;
      _onWaveCompleted();
    }
  }

  void _onWaveCompleted() {
    completedWaves++;
    waveRunning.value = false;
    // 每完成 2 波贈送 1 個障礙物。
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

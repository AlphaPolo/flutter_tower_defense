import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/buildings_manager.dart';
import 'package:tower_defense/manager/enemy_manager.dart';
import 'package:tower_defense/manager/projectile_manager.dart';
import 'package:tower_defense/manager/wave_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';
import 'package:tower_defense/providers/game_event_provider.dart';

import '../model/enemy/enemy.dart';
import '../utils/game_utils.dart';
import '../widget/game/board/board_painter.dart';

typedef CanMovePredicate = bool Function(BoardPoint);

class GameManager {

  late final GameEventProvider eventManager;
  late final ProjectileManager projectileManager;
  late final BuildingsManager buildingsManager;
  late final EnemyManager enemyManager;
  late final WaveManager waveManager;

  int clock = 0;
  Map<BoardPoint, HexagonDirection> guide = {};

  Board? board;
  BoardPoint? spawnLocation;
  BoardPoint? targetLocation;

  bool isGameStart = false;

  /// 被動注入
  GameManager.from(BuildContext context) {
    eventManager = context.read<GameEventProvider>()..init(this);
    projectileManager = context.read<ProjectileManager>()..init(this);
    buildingsManager = context.read<BuildingsManager>()..init(this);
    enemyManager = context.read<EnemyManager>()..init(this);
    waveManager = context.read<WaveManager>()..init(this);
  }

  /// 外部主動注入
  GameManager.setting({
    GameEventProvider? eventManager,
    ProjectileManager? projectileManager,
    BuildingsManager? buildingsManager,
    EnemyManager? enemyManager,
    WaveManager? waveManager,
  }) {
    this.eventManager = (eventManager ?? GameEventProvider())..init(this);
    this.projectileManager = (projectileManager ?? ProjectileManager())..init(this);
    this.buildingsManager = (buildingsManager ?? BuildingsManager())..init(this);
    this.enemyManager = (enemyManager ?? EnemyManager())..init(this);
    this.waveManager = (waveManager ?? WaveManager())..init(this);
  }

  /// 自動注入
  GameManager() {
    eventManager = GameEventProvider()..init(this);
    projectileManager = ProjectileManager()..init(this);
    buildingsManager = BuildingsManager()..init(this);
    enemyManager = EnemyManager()..init(this);
    waveManager = WaveManager()..init(this);
  }

  void dispose() {
  }

  List<Enemy> getEnemies() {
    return enemyManager.enemies;
  }

  void addBuilding(BuildingModel model) {
    if(!isPlaceable(model)) return;

    buildingsManager.addBuilding(model);
    calculator();
    // guide = recalculate(targetLocation!, (position) => isPointCanMove(position));
  }

  void calculator() {
    guide = recalculate(targetLocation!, (position) => isPointCanMove(position));
  }

  bool isPlaceable(BuildingModel model) {
    if(buildingsManager.hasBuildingOn(model.location)) return false; // 已經有建築物
    if(enemyManager.hasEnemyOn(model.location)) return false; // 有敵人正在上面
    if(model.location == spawnLocation || model.location == targetLocation) return false; // 不可蓋在出生點與目的地

    final path = hasPathBetween(
      spawnLocation!,
      targetLocation!,
      isPointCanMove,
      {model.location},
    );

    if(path == null) {
      // 擋住了去路
      return false;
    }

    return true;
  }

  bool isPointCanMove(BoardPoint point) {
    final board = this.board;
    return board!.validateBoardPoint(point) && !buildingsManager.hasBuildingOn(point);
  }

  bool isPointInside(Offset point, double radius) =>
      pow(point.dx, 2) + pow(point.dy, 2) < pow(radius, 2);


  void start() async {
    final board = this.board;

    if(board == null) return;
    if(isGameStart) return;

    isGameStart = true;

    // Duration previousGenerate = 0.ms;
    // Duration generateInterval = 1000.ms;
    Duration currentClock = 0.ms;
    Duration perTick = 16.ms;

    GameUtils.toOffset = (BoardPoint position) {
      final point = board.boardPointToPoint(position);
      return Offset(point.x, point.y);
    };

    waveManager.prepareWaves();

    final listen = Stream.periodic(20.ms, (count) => count).listen((event) {
      enemyManager.notifyListeners();
      projectileManager.notifyListeners();
      buildingsManager.notifyListeners();
    });

    while(isGameStart) {
      // if(wave.isNotEmpty && currentClock - previousGenerate >= generateInterval) {
      //   final enemy = wave.removeFirst();
      //   enemyManager.addEnemy(enemy);
      //   previousGenerate = currentClock;
      // }
      waveManager.tick(this, perTick.inMilliseconds);
      enemyManager.tick(this, perTick.inMilliseconds);      // 更新敵人資訊
      buildingsManager.tick(this, perTick.inMilliseconds);  // 更新防禦塔資訊
      projectileManager.tick(this, perTick.inMilliseconds);

      enemyManager.trimEnemies();                           // 清理該被移除的敵人
      projectileManager.trimProjectile();

      if(enemyManager.isEmpty() && waveManager.isDone) {
        isGameStart = false;
      }

      await Future.delayed(perTick);
      currentClock += perTick;
      clock = currentClock.inMilliseconds;
    }

    projectileManager.projectiles.clear();

    listen.cancel();
  }

  void waveCheck() {

  }
}

/// 只用來搜索是否可以從入口走到終點
List<BoardPoint>? hasPathBetween(BoardPoint from, BoardPoint to, CanMovePredicate canMoveTo, [Set<BoardPoint>? initVisited]) {

  final visited = initVisited ?? {};
  final queue = Queue<List<BoardPoint>>();
  final startPath = [from];
  queue.add(startPath);

  while (queue.isNotEmpty) {
    final currPath = queue.removeFirst();
    final currPos = currPath.last;
    if (currPos == to) {
      return currPath;
    }
    if (visited.contains(currPos)) {
      continue;
    }
    visited.add(currPos);

    final neighbors = currPos.getNeighbors();

    for (final neighbor in neighbors) {

      if (canMoveTo(neighbor) && !visited.contains(neighbor)) {
        final newPath = List<BoardPoint>.from(currPath)..add(neighbor);
        queue.add(newPath);
      }
    }
  }
  return null;
}

// frontier = Queue()
// frontier.put(start )
// came_from = dict()
// came_from[start] = None
//
// while not frontier.empty():
// current = frontier.get()
// for next in graph.neighbors(current):
// if next not in came_from:
// frontier.put(next)
// came_from[next] = current

/// https://www.redblobgames.com/pathfinding/tower-defense/
Map<BoardPoint, HexagonDirection> recalculate(BoardPoint target, CanMovePredicate canMoveTo) {

  final frontier = Queue<BoardPoint>()..add(target);
  final guideMap = <BoardPoint, HexagonDirection> {
    target: HexagonDirection.nw,
  };

  final directions = HexagonDirection.values.toList();

  while(frontier.isNotEmpty) {
    final current = frontier.removeFirst();
    
    current.getNeighbors().forEachIndexed((index, neighbor) {
      if(!canMoveTo(neighbor) || guideMap.containsKey(neighbor)) {
        return;
      }
      frontier.add(neighbor);
      guideMap[neighbor] = directions[index].opposite;
    });
  }

  return guideMap;
}


import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/buildings_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';

import '../model/enemy/enemy.dart';
import '../widget/game/board/board_painter.dart';

typedef CanMovePredicate = bool Function(BoardPoint);

class GameManager {

  late final BuildingsManager buildingsManager;

  int clock = 0;
  List<Enemy> _enemies = [];
  Map<BoardPoint, HexagonDirection> guide = {};

  Board? board;
  BoardPoint? spawnLocation;
  BoardPoint? targetLocation;

  bool isGameStart = false;

  final StreamController<List<Enemy>> _enemiesStreamController = StreamController();
  late final Stream<List<Enemy>> _enemiesEvent = _enemiesStreamController.stream.asBroadcastStream();

  Stream<List<Enemy>> onEnemiesStream() => _enemiesEvent;

  /// 被動注入
  GameManager.from(BuildContext context) {
    buildingsManager = context.read<BuildingsManager>()..init(this);
  }

  /// 外部主動注入
  GameManager.setting({
    BuildingsManager? buildingsManager,
  }) {
    this.buildingsManager = (buildingsManager ?? BuildingsManager())..init(this);
  }

  /// 自動注入
  GameManager() {
    buildingsManager = BuildingsManager()..init(this);
  }

  void dispose() {
    _enemiesStreamController.close();
    // _buildingsStreamController.close();
  }

  List<Enemy> getEnemies() {
    return _enemies;
  }

  void addUnit(Enemy unit) {
    _enemies.add(unit);
  }

  void addBuilding(BuildingModel model) {
    if(!isPlaceable(model)) return;

    buildingsManager.addBuilding(model);
    guide = recalculate(targetLocation!, (position) => isPointCanMove(position));
  }

  bool isPlaceable(BuildingModel model) {
    if(buildingsManager.hasBuildingOn(model.location)) return false; // 已經有建築物
    if(_enemies.any((enemy) => enemy.currentLocation == model.location ||
                            enemy.goalLocation == model.location)) return false; // 有敵人正在上面
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
    if(isGameStart) return;

    isGameStart = true;

    Duration previousGenerate = 0.ms;
    Duration generateInterval = 1000.ms;
    Duration currentClock = 0.ms;
    Duration perTick = 16.ms;

    Enemy.toOffset = (BoardPoint position) {
      final point = board!.boardPointToPoint(position);
      return Offset(point.x, point.y);
    };

    // final enemy = Enemy(spawnLocation!, const EnemyStatus(totalHp: 100, currentHp: 100, speed: 1));
    // enemy.init(this);
    // addUnit(enemy);

    final wave = Queue.of(List.generate(5, (index) {
      final enemy = Enemy(spawnLocation!, const EnemyStatus(totalHp: 100, currentHp: 100, speed: 1));
      enemy.init(this);
      return enemy;
    }));

    while(isGameStart) {
      if(wave.isNotEmpty && currentClock - previousGenerate >= generateInterval) {
        final enemy = wave.removeFirst();
        addUnit(enemy);
        previousGenerate = currentClock;
      }

      for (final enemy in _enemies) {
        enemy.tick(this, perTick.inMilliseconds);
      }

      buildingsManager.tick(this, perTick.inMilliseconds);

      _enemies.removeWhere((enemy) => enemy.currentLocation == targetLocation);
      _enemiesStreamController.add(_enemies);
      buildingsManager.notifyListeners();
      // _buildingsStreamController.add(buildingsMap.values.toList());

      if(_enemies.isEmpty && wave.isEmpty) {
        isGameStart = false;
      }

      await Future.delayed(perTick);
      currentClock += perTick;
    }
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


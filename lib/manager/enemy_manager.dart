import 'dart:async';

import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/widget/game/board/board_painter.dart';

import '../model/enemy/enemy.dart';

class EnemyManager {

  late final GameManager gameManager;

  List<Enemy> enemies = [];

  final StreamController<List<Enemy>> _enemiesStreamController = StreamController();
  late final Stream<List<Enemy>> _enemiesEvent = _enemiesStreamController.stream.asBroadcastStream();

  Stream<List<Enemy>> onEnemiesStream() => _enemiesEvent;

  void init(GameManager manager) {
    gameManager = manager;
  }

  void dispose() {
    _enemiesStreamController.close();
  }

  void tick(GameManager manager, int clock) {
    for (final enemy in enemies) {
      enemy.tick(gameManager, clock);
    }
  }

  void addEnemy(Enemy enemy) {
    enemy.init(gameManager);
    enemies.add(enemy);
  }

  void trimEnemies() {
    enemies.removeWhere((enemy) {
      if(enemy.currentLocation == gameManager.targetLocation) return true;  // 當敵人到達主堡時移除
      // 當敵人死亡時移除
      return false;
    });
  }

  bool isEmpty() => enemies.isEmpty;

  bool hasEnemyOn(BoardPoint point) {
    return enemies.any((enemy) {
      if(enemy.currentLocation == point) return true;
      if(enemy.goalLocation == point) return true;
      return false;
    });
  }

  void notifyListeners() {
    _enemiesStreamController.add(enemies);
  }
}
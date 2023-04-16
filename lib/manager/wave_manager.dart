import 'dart:collection';

import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/game_manager.dart';

import '../model/enemy/enemy.dart';

class WaveManager {

  late final GameManager gameManager;

  Queue<Wave> waves = Queue();
  Wave? currentWave;

  Duration currentClock = Duration.zero;
  Duration previousGenerate = Duration.zero;

  void init(GameManager manager) {
    gameManager = manager;
  }

  void dispose() {
  }

  void tick(GameManager manager, int clock) {
    currentClock += clock.ms;

    if(currentWave == null && waves.isNotEmpty) {
      currentWave = waves.removeFirst();
    }

    final wave = currentWave;

    if(wave == null) return;  /// 如果wave還是空的

    if((currentClock - previousGenerate).inMilliseconds >= wave.interval) {
      final iterator = wave.iterator;
      if(iterator.moveNext()) {
        final enemy = iterator.current;
        gameManager.enemyManager.addEnemy(enemy);
        previousGenerate = currentClock;
      }
      else {
        currentWave = null;
      }
    }
  }

  void prepareWaves() {
    final wave = Wave(1000, 15, Enemy(gameManager.spawnLocation!, const EnemyStatus(totalHp: 100, currentHp: 100, speed: 1.5)));
    waves.add(wave);
  }

  bool get isDone {
    if(waves.isNotEmpty) return false;
    if(currentWave != null) return false;
    return true;
  }

}


class Wave {
  final int interval;
  final int count;
  late final Iterator<Enemy> iterator;

  Wave(
    this.interval,
    this.count,
    Enemy prototype,
  ) {
    iterator = enemyGenerator(prototype).iterator;
  }

  Iterable<Enemy> enemyGenerator(Enemy prototype) sync* {
    yield prototype.copyWith()..id = 1;
    for (int i = 0; i < count - 1; i++) {
      yield prototype.copyWith();
    }
  }
}
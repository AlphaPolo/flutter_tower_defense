import 'package:tower_defense/manager/game_manager.dart';

import '../enemy/enemy.dart';

abstract class BaseEffect implements Comparable<BaseEffect> {
  void attach(GameManager manager, Enemy enemy);
  void tick(GameManager manager, int timeDelta);
  void onEnd(GameManager manager, Enemy enemy);
  EnemyStatus calc(GameManager manager, EnemyStatus status);

  bool get dead;
  int get order;

  @override
  int compareTo(other) {
    return order.compareTo(other.order);
  }
}

/// 基本的時間狀態implements
abstract class DefaultTimerEffect extends BaseEffect {

  DefaultTimerEffect(this.lifetime);

  int clock = 0;
  int lifetime;

  @override
  bool dead = false;

  @override
  void tick(GameManager manager, int timeDelta) {
    clock += timeDelta;

    if(dead) return;

    if(clock >= lifetime) dead = true;
  }

  @override
  void attach(GameManager manager, Enemy enemy) {}

  @override
  void onEnd(GameManager manager, Enemy enemy) {}

}



import 'dart:ui';

import 'package:tower_defense/manager/game_manager.dart';

import '../enemy/enemy.dart';

class Projectile {
  double damage;
  Offset direction;
  Offset position;
  double speed;
  Enemy? target;

  Projectile(
    this.damage,
    this.position,
    this.direction,
    this.speed,
  );

  void tick(GameManager manager, int clock) {

  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/game_manager.dart';

import '../enemy/enemy.dart';

class Projectile {
  double damage;
  Offset direction;
  Offset position;
  double speed;

  Enemy? target;
  Offset? goal;
  int lifeTime = 0;
  int clock = 0;
  bool isDead = false;

  Projectile(
    this.damage,
    this.position,
    this.direction,
    this.speed,
  );

  Widget render() {
    return const SizedBox.shrink();
  }

  void tick(GameManager manager, int clock) {
    this.clock += clock;

    if(this.clock >= lifeTime) {
      isDead = true;
    }
  }
}


class NormalProjectile extends Projectile {

  NormalProjectile(
    super.damage,
    super.position,
    super.direction,
    super.speed,
  );

  @override
  Widget render() {

    return TweenAnimationBuilder(
        key: ObjectKey(this),
        tween: RectTween(
          begin: Rect.fromCircle(center: position, radius: 5),
          end: Rect.fromCircle(center: goal!, radius: 5),
        ),
        duration: lifeTime.ms,
        builder: (BuildContext context, Rect? value, Widget? child) {
          return Positioned.fromRect(rect: value!, child: child!);
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        )
    );
  }

}

import 'package:collection/collection.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/projectile/projectile.dart';
import 'package:tower_defense/utils/game_utils.dart';

import '../enemy/enemy.dart';

class FlameProjectile extends Projectile {
  FlameProjectile(
    super.damage,
    super.position,
    super.direction,
    super.speed,
    this.length,
  );

  double length;
  // Set<Enemy> marked = {};

  @override
  void init(GameManager manager) {
    final toward = position + Offset.fromDirection(direction.direction, manager.board!.hexagonRadius * length);
    goal = toward;
    lifeTime = calculatorFlyingTime(position, toward, speed);
  }

  @override
  void tick(GameManager manager, int timeDelta) {
    super.tick(manager, timeDelta);
    if(isDead) return;

    final current = Offset.lerp(position, goal, clock / lifeTime);
    GameUtils.getEnemiesHasRenderOffset(manager)
             // .whereNot(marked.contains)
             .where((enemy) => (enemy.renderOffset! - current!).distance <= 40)
             .forEach((enemy) {
      enemy.dealDamage(damage);
      // marked.add(enemy);
    });
  }


  @override
  Widget render() {

    return TweenAnimationBuilder(
        key: ObjectKey(this),
        tween: RectTween(
          begin: Rect.fromCircle(center: position, radius: 5),
          end: Rect.fromCircle(center: goal!, radius: 10),
        ),
        duration: lifeTime.ms,
        builder: (BuildContext context, Rect? value, Widget? child) {
          return Positioned.fromRect(rect: value!, child: child!);
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        )
    );
  }
}
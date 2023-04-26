import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/constant/game_constant.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/model/effects/slow_movement_effect.dart';
import 'package:tower_defense/model/effects/stat_calc_type.dart';
import 'package:tower_defense/model/projectile/projectile.dart';
import 'package:tower_defense/utils/game_utils.dart';

import '../../manager/game_manager.dart';
import '../enemy/enemy.dart';

class FreezeProjectile extends Projectile {
  FreezeProjectile(
    double damage,
    Offset position,
    double speed, {
    int duration = 1000,
    this.fromRadius = 0,
    required this.toRadius,
  }) : currentRadius = fromRadius,
        super(damage, position, Offset.zero, speed) {
    lifeTime = duration;
  }

  final double fromRadius;
  final double toRadius;
  double currentRadius;
  final Set<Enemy> isEffected = {};

  @override
  void init(GameManager manager) {
  }

  @override
  void tick(GameManager manager, int timeDelta) {
    clock += timeDelta;

    if(isDead) return;
    if (clock >= lifeTime) {
      isDead = true;
    }

    currentRadius = lerpDouble(fromRadius, toRadius, clock / lifeTime)!;
    GameUtils.getEnemiesHasRenderOffset(manager)
             .whereNot(isEffected.contains)
             .where((enemy) => (enemy.renderOffset! - position).distance < currentRadius)
             .forEach((enemy) {
      isEffected.add(enemy);
      enemy.addEffect(SlowMovementEffect(
        kFrozenEffectType,
        800,
        enemy,
        StatCalcType.multi,
        0.3,
      ));
    });

  }

  @override
  Widget render() {
    return TweenAnimationBuilder(
      key: ObjectKey(this),
      tween: RectTween(
        begin: Rect.fromCircle(center: position, radius: fromRadius),
        end: Rect.fromCircle(center: position, radius: toRadius),
      ),
      duration: lifeTime.ms,
      builder: (context, value, child) {
        return Positioned.fromRect(rect: value!, child: child!);
      },
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.transparent,
                Colors.blue.withOpacity(0.5),
              ],
              stops: const [
                0.5,
                1,
              ],
            ),
            // border: Border.all(
            //   width: 0.01,
            //   color: Colors.redAccent,
            // ),
          ),
        ),
      ),
    );
  }


}

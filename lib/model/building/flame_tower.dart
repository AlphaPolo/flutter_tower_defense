
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/enemy/enemy.dart';
import 'package:tower_defense/model/projectile/flame_projectile.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';

import '../../utils/game_utils.dart';
import '../../widget/game/board/board_painter.dart';
import '../projectile/projectile.dart';
import 'building_model.dart';

class FlameTower extends BuildingModel {
  FlameTower({required super.rotate, required super.location, this.rotateSpeed = 0.08})
      : super(
          type: BuildingType.tower,
          cost: 60,
          damage: 0.2,
          range: 6,
          fireCD: 100,
        );

  FlameTower.template()
      : this(
          rotate: 0,
          location: const BoardPoint(0, 0),
        );

  double rotateSpeed;
  Iterator<double>? turretRotator;

  @override
  Widget getRenderWidget({Key? key}) {
    return FlameTowerWidget(key: key, model: this);
  }

  @override
  void tick(GameManager manager, int timeDelta) {
    prepareShoot = (prepareShoot - timeDelta).clamp(0, fireCD);
    final rotator = turretRotator;

    if(rotator != null) {
      if(rotator.moveNext()) {
        // direction = rotator.current;
        direction = rotator.current;
        attemptShoot(manager, target!);
        return;
      }
      else {
        turretRotator = null;
        target = null;
      }
    }

    final self = GameUtils.toOffset(location);
    final enemies = GameUtils.getEnemiesInRangeTuple(manager, self, range);
    final degreeMin = minBy(enemies, (tuple) => (tuple.item1.direction - direction).abs());

    if(degreeMin != null) {
      target = degreeMin.item2;
      turretRotator = lerpToTarget(manager, degreeMin.item2).iterator;
    }
  }

  Iterable<double> lerpToTarget(GameManager manager, Enemy enemy) sync* {
    bool isValid() => !enemy.isGoal && !enemy.isDead;
    final position = GameUtils.toOffset(location);
    while(isValid()) {
      final enemyBody = enemy.renderOffset;
      if(enemyBody == null) return;
      final diff = (enemyBody - position);

      if(!GameUtils.isInsideRange(manager.board!, diff, range)) return;
      final deltaAngle = diff.direction - direction;
      final rotateAmount = min(rotateSpeed, deltaAngle.abs());

      // Check the direction to rotate
      final directionToRotate = deltaAngle.sign;
      yield direction + directionToRotate * rotateAmount;
    }
  }

  @override
  Projectile createProjectile(GameManager manager, Enemy enemy) {
    Random r = Random();
    const fixRange = 0.2;
    final fix = r.nextDouble() * (fixRange * 2) - fixRange;
    final projectile = FlameProjectile(
      damage,
      GameUtils.toOffset(location) + Offset.fromDirection(direction, 32),  /// 讓砲彈從接近炮口的地方出來
      Offset.fromDirection(direction + fix),
      0.5,
      range / 2,
    );
    return projectile;
  }

}


import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/model/projectile/freeze_projectile.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';

import '../../manager/game_manager.dart';
import '../../utils/game_utils.dart';
import '../../widget/game/board/board_painter.dart';
import '../enemy/enemy.dart';
import '../projectile/projectile.dart';
import 'building_model.dart';

class FreezingTower extends BuildingModel {
  FreezingTower({required super.rotate, required super.location})
      : super(
          type: BuildingType.tower,
          cost: 10,
          damage: 1,
          range: 2.5,
          fireCD: 1500,
        );

  FreezingTower.template()
      : this(
          rotate: 0,
          location: const BoardPoint(0, 0),
        );

  @override
  void tick(GameManager manager, int timeDelta) {
    prepareShoot = (prepareShoot - timeDelta).clamp(0, fireCD);
    if(prepareShoot > 0) return;
    final enemies = manager.getEnemies();
    if(enemies.isNotEmpty) {
      attemptShoot(manager, manager.getEnemies().first);
    }
  }

  @override
  Projectile createProjectile(GameManager manager, Enemy enemy) {
    final projectile = FreezeProjectile(
      damage,
      GameUtils.toOffset(location),
      1,
      toRadius: manager.board!.hexagonRadius * range,
      duration: 2000,
    );
    projectile.target = enemy;
    return projectile;
  }

  @override
  Widget getRenderWidget({Key? key}) {
    return FreezingTowerWidget(key: key, model: this);
  }
}


import 'package:flutter/material.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/projectile/thunder_projectile.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';

import '../../utils/game_utils.dart';
import '../../widget/game/board/board_painter.dart';
import '../enemy/enemy.dart';
import '../projectile/projectile.dart';
import 'building_model.dart';

class ThunderTower extends BuildingModel {
  ThunderTower({required super.rotate, required super.location})
      : super(
    type: BuildingType.tower,
    cost: 10,
    damage: 1,
    range: 2,
    fireCD: 2000,
  );

  ThunderTower.template()
      : this(
    rotate: 0,
    location: const BoardPoint(0, 0),
  );

  @override
  Projectile createProjectile(GameManager manager, Enemy enemy) {
    final projectile = ThunderProjectile(
      damage,
      GameUtils.toOffset(location) + Offset.fromDirection(direction, 32),  /// 讓砲彈從接近炮口的地方出來
      Offset.fromDirection(direction),
      1,
      4,
      chainDistance: 5,
    );
    projectile.target = enemy;
    return projectile;
  }


  @override
  Widget getRenderWidget({Key? key}) {
    return ThunderTowerWidget(model: this);
  }
}
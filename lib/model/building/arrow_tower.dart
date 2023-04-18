import 'package:flutter/material.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';

import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

const spinSpeed = 0.2;

class ArrowTower extends BuildingModel {

  ArrowTower({required super.rotate, required super.location})
      : super(
    type: BuildingType.tower,
    cost: 10,
    damage: 1,
    range: 2,
  );

  ArrowTower.template()
      : this(
    rotate: 0,
    location: const BoardPoint(0, 0),
  );

  @override
  void tick(GameManager manager, int clock) {
    direction += spinSpeed;
  }



  @override
  Widget getRenderWidget({Key? key}) {
    return AirTowerWidget(key: key, model: this);
  }

}

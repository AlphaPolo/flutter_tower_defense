import 'package:flutter/material.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';

import '../../widget/game/board/board_painter.dart';
import '../../widget/game/building/tower_widget.dart';

class ObstacleTower extends BuildingModel {
  ObstacleTower({required super.location})
      : super(
    type: BuildingType.tower,
    rotate: 0,
    cost: 20,
    damage: 0,
    range: 0,
  );

  ObstacleTower.template()
      : this(location: const BoardPoint(0, 0));

  @override
  void tick(GameManager manager, int timeDelta) {

  }

  @override
  Widget getRenderWidget({Key? key}) {
    return ObstacleTowerWidget(key: key, model: this);
  }
}
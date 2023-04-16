
import 'package:flutter/material.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';

import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

class CanonTower extends BuildingModel {
  CanonTower({required super.rotate, required super.location})
      : super(
    type: BuildingType.tower,
    cost: 10,
    damage: 1,
    range: 2,
  );

  CanonTower.template()
      : this(
    rotate: 0,
    location: const BoardPoint(0, 0),
  );

  @override
  Widget getRenderWidget({Key? key}) {
    return ThunderTowerWidget(model: this);
  }
}
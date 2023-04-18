
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';
import 'package:tuple/tuple.dart';

import '../../utils/game_utils.dart';
import '../../widget/game/board/board_painter.dart';
import '../enemy/enemy.dart';
import 'building_model.dart';

class FlameTower extends BuildingModel {
  FlameTower({required super.rotate, required super.location})
      : super(
          type: BuildingType.tower,
          cost: 10,
          damage: 1,
          range: 2,
        );

  FlameTower.template()
      : this(
          rotate: 0,
          location: const BoardPoint(0, 0),
        );

  @override
  Widget getRenderWidget({Key? key}) {
    return FlameTowerWidget(key: key, model: this);
  }

  @override
  void tick(GameManager manager, int clock) {
    final self = GameUtils.toOffset(location);
    // final board = manager.board!;
    // manager.getEnemies()
    //     .where((element) => element.renderOffset != null)
    //     .map((e) => Tuple2(e.renderOffset! - self, e))
    //     .where((element) => isInsideRange(board, element.item1));
        // .where((element) => element.renderOffset - self);
  }

}

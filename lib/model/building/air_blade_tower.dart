import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';
import 'package:tuple/tuple.dart';

import '../../utils/game_utils.dart';
import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

const spinSpeed = 0.2;

class AirBladeTower extends BuildingModel {

  AirBladeTower({required super.rotate, required super.location})
      : super(
    type: BuildingType.tower,
    cost: 60,
    damage: 7,
    range: 3,
  );

  AirBladeTower.template()
      : this(
    rotate: 0,
    location: const BoardPoint(0, 0),
  );

  @override
  void tick(GameManager manager, int timeDelta) {
    direction += spinSpeed;

    final current = GameUtils.toOffset(location);
    // manager.getEnemies().firstOrNull?.let((e) {
    //   final diff = e.renderOffset! - current;
    //   final isBetween = isRadianInBetween(direction, direction+(15*degrees2Radians), diff.direction);
    //   final isInside = isInsideRange(manager.board!, diff);
    //   print('isBetween: $isBetween, isInside: $isInside');
    // });


    final targets = manager
        .getEnemies()
        .where((element) => element.renderOffset != null)
        .map((e) => Tuple2(e.renderOffset! - current, e))
        .where((element) => isInsideRange(manager.board!, element.item1))
        .where((element) => isRadianInBetween(direction, direction+(25*degrees2Radians), element.item1.direction));

    for (final Tuple2(item1: diff, item2: enemy) in targets) {
      enemy.dealDamage(damage);
    }
  }

  double normalizeRadian(double radian) {
    return radian % (2 * pi);
  }

  bool isRadianInBetween(double startRadian, double endRadian, double targetRadian) {
    // 规范化弧度到 0 到 2π 之间
    startRadian = normalizeRadian(startRadian);
    endRadian = normalizeRadian(endRadian);
    targetRadian = normalizeRadian(targetRadian);

    // 如果起始角大于结束角（跨越 0 的情况）
    if (startRadian > endRadian) {
      return targetRadian >= startRadian || targetRadian <= endRadian;
    } else {
      return targetRadian >= startRadian && targetRadian <= endRadian;
    }
  }

  @override
  Widget getRenderWidget({Key? key}) {
    return AirTowerWidget(key: key, model: this);
  }

}

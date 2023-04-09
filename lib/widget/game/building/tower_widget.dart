import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tower_defense/widget/game/board/hexagon_widget.dart';

import '../../../model/building/building_model.dart';

class TowerWidget extends StatelessWidget {
  const TowerWidget({super.key, required this.model});

  final BuildingModel model;

  double getAngle(double degree) {
    return degree * math.pi / 180.0;
  }

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
      // angle: getAngle(model.direction),
      child: FractionalTranslation(
        translation: const Offset(0.5, 0),
        child: Container(
          color: Colors.blue,
          width: 25,
          height: 5,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const HexagonWidget(
          color: Colors.blueGrey,
        ),
        Center(child: buildTurret()),
        // debugRange()
      ],
    );
  }

  Widget debugRange() {
    return Center(
      child: Transform.scale(
        scale: model.range * 32 * 2,
        child: Container(
          width: 1,
          height: 1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: 0.01,
              color: Colors.redAccent,
            ),
          ),
        ),
      ),
    );
  }
}

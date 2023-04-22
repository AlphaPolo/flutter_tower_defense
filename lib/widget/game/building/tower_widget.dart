library towers;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tower_defense/widget/game/board/hexagon_widget.dart';

import '../../../model/building/building_model.dart';

part 'obstacle_tower_widget.dart';



double _getAngle(double degree) {
  return degree * math.pi / 180.0;
}

Widget _buildStackBase({required List<Widget> children}) {
  return Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: children,
  );
}

Widget _debugRange(BuildingModel model) {
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

// class TowerWidgetBuilder extends StatelessWidget {
//   const TowerWidgetBuilder({super.key, required this.model});
//
//   final BuildingModel model;
//
//
//   Widget switchModel() {
//     switch(model.runtimeType) {
//       case FlameTower: return FlameTowerWidget(model: model);
//       case FreezingTower: return FreezingTowerWidget(model: model);
//       case ArrowTower: return AirTowerWidget(model: model);
//       case CanonTower: return ThunderTowerWidget(model: model);
//     }
//     return const SizedBox.shrink();
//   }
//
//
//   // Widget buildTurret() {
//   //   return Transform.rotate(
//   //     // duration: 100.ms,
//   //     // turns: model.direction / math.pi / 2.0,
//   //     angle: model.direction,
//   //     child: FractionalTranslation(
//   //       translation: const Offset(0.5, 0),
//   //       child: Container(
//   //         color: Colors.blue,
//   //         width: 25,
//   //         height: 5,
//   //       ),
//   //     ),
//   //   );
//   // }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return switchModel();
//   }
// }


class FreezingTowerWidget extends StatelessWidget {
  const FreezingTowerWidget({super.key, required this.model});
  final BuildingModel model;

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
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
    return _buildStackBase(
      children: [
        const HexagonWidget(color: Colors.blueGrey),
        Center(child: buildTurret()),
        // debugRange()
      ],
    );
  }
}

class FlameTowerWidget extends StatelessWidget {
  const FlameTowerWidget({super.key, required this.model});
  final BuildingModel model;

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
      child: FractionalTranslation(
        translation: const Offset(0.5, 0),
        child: Container(
          color: Colors.redAccent,
          width: 25,
          height: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStackBase(
      children: [
        const HexagonWidget(color: Colors.blueGrey),
        Center(child: buildTurret()),
        // debugRange()
      ],
    );
  }
}

class ThunderTowerWidget extends StatelessWidget {
  const ThunderTowerWidget({super.key, required this.model});
  final BuildingModel model;

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
      child: FractionalTranslation(
        translation: const Offset(0.5, 0),
        child: Container(
          color: Colors.amberAccent,
          width: 25,
          height: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStackBase(
      children: [
        const HexagonWidget(color: Colors.blueGrey),
        Center(child: buildTurret()),
        // debugRange()
      ],
    );
  }
}

class AirTowerWidget extends StatelessWidget {
  const AirTowerWidget({super.key, required this.model});
  final BuildingModel model;

  Widget buildTurret() {
    return Transform.rotate(
      angle: model.direction,
      child: FractionalTranslation(
        translation: const Offset(0.5, 0),
        child: Container(
          color: Colors.blueGrey,
          width: 90,
          height: 5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildStackBase(
      children: [
        const HexagonWidget(color: Colors.blueGrey),
        Center(child: buildTurret()),
        // debugRange()
      ],
    );
  }
}



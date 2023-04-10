
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tuple/tuple.dart';

import '../../widget/game/board/board_painter.dart';
import '../enemy/enemy.dart';

enum BuildingType {
  tower,
  wall,
  trap,
}

class BuildingModel {

  BuildingType type;
  BoardPoint location;
  int cost;
  int damage;
  double range;
  int rotate;
  double direction;

  Enemy? target;

  BuildingModel({
    required this.type,
    required this.location,
    required this.cost,
    required this.damage,
    required this.range,
    required this.rotate,
    this.direction = 0,
  });

  bool isInsideRange(Board board, Offset diff) {
    return diff.distance <= board.hexagonRadius * range;
  }

  void tick(GameManager manager, int clock) {
    final board = manager.board!;

    if(target == null) {
      final current = Enemy.toOffset!(location);
      final s = manager
          .getEnemies()
          .where((element) => element.renderOffset != null)
          .map((e) => Tuple2(e.renderOffset! - current, e))
          .where((element) => isInsideRange(board, element.item1));

      target = minBy(s, (tuple) => tuple.item1.distance)?.item2;
    }

    target?.let((enemy) {
      /// 敵人已經不見了
      if(enemy.renderOffset == null) {
        target = null;
        return;
      }
      /// 敵人離開射程範圍
      if(!isInsideRange(board, enemy.renderOffset! - Enemy.toOffset!(location)))
      {
        target = null;
        return;
      }
      lookAtPosition(manager.board!, enemy.renderOffset!);
    });
  }

  void lookAtPosition(Board board, Offset point) {
    Offset toOffset(BoardPoint point) => board.boardPointToPoint(point).let((e) => Offset(e.x, e.y));
    final target = point;
    final from = toOffset(location);

    final diff = (target - from);
    final range = this.range * board.hexagonRadius;
    if(diff.distance >= range) {
      return;
    }
    direction = diff.direction;
    // buildings = {...buildings};
    // notifyListeners();
  }

  BuildingModel copyWith({
    BuildingType? type,
    BoardPoint? location,
    int? cost,
    int? damage,
    double? range,
    int? rotate,
    double? direction,
  }) {
    return BuildingModel(
      type: type ?? this.type,
      location: location ?? this.location,
      cost: cost ?? this.cost,
      damage: damage ?? this.damage,
      range: range ?? this.range,
      rotate: rotate ?? this.rotate,
      direction: direction ?? this.direction,
    );
  }
}



// class BuildingCostPreview {
//   int costMoney;
//   int cost;
// }
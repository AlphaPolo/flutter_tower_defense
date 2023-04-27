

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/projectile/projectile.dart';
import 'package:tower_defense/utils/game_utils.dart';
import 'package:tuple/tuple.dart';

import '../../widget/game/board/board_painter.dart';
import '../enemy/enemy.dart';

enum BuildingType {
  tower,
  wall,
  trap,
}

class BuildingModel with RenderTower {

  BuildingType type;
  BoardPoint location;
  int cost;
  int fireCD;
  double damage;
  double range;
  int rotate;
  double direction;

  /// not data
  Enemy? target;
  int prepareShoot = 0;

  BuildingModel({
    required this.type,
    required this.location,
    required this.cost,
    required this.damage,
    required this.range,
    required this.rotate,
    this.fireCD = 300,
    this.direction = 0,
  });

  bool isInsideRange(Board board, Offset diff) {
    return diff.distance <= board.hexagonRadius * range;
  }

  void tick(GameManager manager, int timeDelta) {
    prepareShoot = (prepareShoot - timeDelta).clamp(0, fireCD);
    final board = manager.board!;
    if(prepareShoot > 0) return;

    if(target == null) {
      final current = GameUtils.toOffset(location);
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
      if(!isInsideRange(board, enemy.renderOffset! - GameUtils.toOffset(location)) || enemy.isDead || enemy.isGoal)
      {
        target = null;
        return;
      }
      lookAtPosition(manager.board!, enemy.renderOffset!);
      attemptShoot(manager, enemy);
    });
  }

  void lookAtPosition(Board board, Offset point) {
    Offset toOffset(BoardPoint point) => board.boardPointToPoint(point).let((e) => Offset(e.x, e.y));
    final target = point;
    final from = toOffset(location);

    final diff = (target - from);
    direction = diff.direction;
  }


  BuildingModel copyWith({
    BuildingType? type,
    BoardPoint? location,
    int? cost,
    double? damage,
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

  void attemptShoot(GameManager manager, Enemy enemy) {
    if (prepareShoot > 0) return;
    final projectile = createProjectile(manager, enemy);
    manager.projectileManager.addProjectile(projectile);
    prepareShoot = fireCD;
  }

  Projectile createProjectile(GameManager manager, Enemy enemy) {
    final projectile = NormalProjectile(
      1,
      GameUtils.toOffset(location) + Offset.fromDirection(direction, 32),  /// 讓砲彈從接近炮口的地方出來
      Offset.fromDirection(direction),
      1,
    );
    projectile.target = enemy;
    return projectile;
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'location': location,
      'cost': cost,
      'fireCD': fireCD,
      'damage': damage,
      'range': range,
      'rotate': rotate,
      'direction': direction,
    };
  }

  BuildingModel.fromMap(Map<String, dynamic> map) :
    this(
      type: map['type'] as BuildingType,
      location: map['location'] as BoardPoint,
      cost: map['cost'] as int,
      fireCD: map['fireCD'] as int,
      damage: map['damage'] as double,
      range: map['range'] as double,
      rotate: map['rotate'] as int,
      direction: map['direction'] as double,
    );

  @override
  Widget getRenderWidget({Key? key}) {
    return const SizedBox.shrink();
  }
}


abstract class RenderTower {
  Widget getRenderWidget({Key? key});
}



// class BuildingCostPreview {
//   int costMoney;
//   int cost;
// }
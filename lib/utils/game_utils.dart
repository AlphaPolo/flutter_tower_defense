import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:tower_defense/model/enemy/enemy.dart';
import 'package:tuple/tuple.dart';

import '../manager/game_manager.dart';
import '../widget/game/board/board_painter.dart';

class GameUtils {
  const GameUtils._();

  static late Offset Function(BoardPoint) toOffset;

  static Iterable<Enemy> getEnemiesHasRenderOffset(GameManager manager) {
    return manager
        .getEnemies()
        .where((element) => element.renderOffset != null);
  }

  static Enemy? findNearestEnemyByBoardPoint(GameManager manager, BoardPoint current, double range) {
    return findNearestEnemyByOffset(manager, toOffset(current), range);
  }

  static Enemy? findNearestEnemyByOffset(GameManager manager, Offset current, double range) {
    final enemies = getEnemiesHasRenderOffset(manager)
        .map((e) => toOffsetEnemyTuple(e, current))
        .where((element) => isInsideRange(manager.board!, element.item1, range));

    return minBy(enemies, (tuple) => tuple.item1.distance)?.item2;
  }

  static Tuple2<Offset, Enemy> toOffsetEnemyTuple(Enemy enemy, Offset current) {
    return Tuple2(enemy.renderOffset! - current, enemy);
  }

  static bool isInsideRange(Board board, Offset diff, double radius) {
    return diff.distance <= board.hexagonRadius * radius;
  }
}
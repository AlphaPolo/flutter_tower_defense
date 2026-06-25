import 'dart:collection';

import 'package:collection/collection.dart';

import 'hex.dart';

typedef CanMovePredicate = bool Function(BoardPoint);

/// 只用來搜索是否可以從入口走到終點（BFS）。
List<BoardPoint>? hasPathBetween(
  BoardPoint from,
  BoardPoint to,
  CanMovePredicate canMoveTo, [
  Set<BoardPoint>? initVisited,
]) {
  final visited = initVisited ?? {};
  final queue = Queue<List<BoardPoint>>();
  final startPath = [from];
  queue.add(startPath);

  while (queue.isNotEmpty) {
    final currPath = queue.removeFirst();
    final currPos = currPath.last;
    if (currPos == to) {
      return currPath;
    }
    if (visited.contains(currPos)) {
      continue;
    }
    visited.add(currPos);

    final neighbors = currPos.getNeighbors();

    for (final neighbor in neighbors) {
      if (canMoveTo(neighbor) && !visited.contains(neighbor)) {
        final newPath = List<BoardPoint>.from(currPath)..add(neighbor);
        queue.add(newPath);
      }
    }
  }
  return null;
}

/// 從終點往回 BFS，建立一張「每個格子該往哪個方向走」的 flow field。
/// https://www.redblobgames.com/pathfinding/tower-defense/
Map<BoardPoint, HexagonDirection> recalculate(
  BoardPoint target,
  CanMovePredicate canMoveTo,
) {
  final frontier = Queue<BoardPoint>()..add(target);
  final guideMap = <BoardPoint, HexagonDirection>{
    target: HexagonDirection.nw,
  };

  final directions = HexagonDirection.values.toList();

  while (frontier.isNotEmpty) {
    final current = frontier.removeFirst();

    current.getNeighbors().forEachIndexed((index, neighbor) {
      if (!canMoveTo(neighbor) || guideMap.containsKey(neighbor)) {
        return;
      }
      frontier.add(neighbor);
      guideMap[neighbor] = directions[index].opposite;
    });
  }

  return guideMap;
}

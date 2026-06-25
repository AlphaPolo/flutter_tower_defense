import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/board/pathfinding.dart';

void main() {
  group('路徑測試', () {
    late Board board;
    late Set<BoardPoint> blocked;
    const radius = 2;
    const target = BoardPoint(0, -radius);
    const spawn = BoardPoint(0, radius);

    bool canMove(BoardPoint p) =>
        board.validateBoardPoint(p) && !blocked.contains(p);

    /// 模擬 TowerDefenseGame.isPlaceable + 放置：擋住路就不能蓋。
    bool tryPlace(BoardPoint p) {
      if (blocked.contains(p)) return false;
      if (p == spawn || p == target) return false;
      final path = hasPathBetween(spawn, target, canMove, {p});
      if (path == null) return false;
      blocked.add(p);
      return true;
    }

    setUp(() {
      board = Board(boardRadius: radius, hexagonRadius: 1, hexagonMargin: 0);
      blocked = {};
    });

    test('放置建築物測試', () {
      const placeLocation = BoardPoint(0, 0);
      expect(canMove(placeLocation), isTrue, reason: '還沒放置');

      expect(tryPlace(placeLocation), isTrue);
      expect(canMove(placeLocation), isFalse, reason: '放置後應該會不可行走');
    });

    test('擋住出口（終點）只會成功放置2個', () {
      final neighbors = target.getNeighbors().where(board.validateBoardPoint);
      var placed = 0;
      for (final n in neighbors) {
        if (tryPlace(n)) placed++;
      }
      expect(placed, 2, reason: '3個都放置後出口會被擋住，所以只會成功2個');
    });

    test('擋住入口（出生點）只會成功放置2個', () {
      final neighbors = spawn.getNeighbors().where(board.validateBoardPoint);
      var placed = 0;
      for (final n in neighbors) {
        if (tryPlace(n)) placed++;
      }
      expect(placed, 2, reason: '3個都放置後入口會被擋住，所以只會成功2個');
    });
  });
}

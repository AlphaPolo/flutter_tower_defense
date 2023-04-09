import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';
import 'package:tower_defense/model/building/freezing_tower.dart';
import 'package:tower_defense/widget/game/board/board_painter.dart';

void main() {

  group('路徑測試', () {
    late GameManager manager;
    late Board board;
    const radius = 2;

    BuildingModel emptyBuilding(BoardPoint location) => FreezingTower.template().copyWith(location: location);

    setUp(() {
      board = Board(
        boardRadius: 2,
        hexagonRadius: 1,
        hexagonMargin: 0,
      );
      manager = GameManager();
      manager.board = board;
      manager.targetLocation = const BoardPoint(0, -radius);
      manager.spawnLocation = const BoardPoint(0, radius);
    });

    test('放置建築物測試', () {
      const placeLocation = BoardPoint(0, 0);
      expect(manager.isPointCanMove(placeLocation), isTrue, reason: '還沒放置');

      manager.addBuilding(emptyBuilding(placeLocation));
      expect(manager.isPointCanMove(placeLocation), isFalse, reason: '放置後應該會不可行走');
    });

    group('不可擋住入口及出口測試', () {

      test('擋住出口', () {
        final neighbors = manager.targetLocation!.getNeighbors().where(board.validateBoardPoint);

        for (final neighbor in neighbors) {
          manager.addBuilding(emptyBuilding(neighbor));
        }

        expect(manager.buildings.length, 2, reason: '因為3個都放置後出口會被擋住，所以成功放置的建築只會有2個');
      });

      test('擋住入口', () {
        final neighbors = manager.spawnLocation!.getNeighbors().where(board.validateBoardPoint);

        for (final neighbor in neighbors) {
          manager.addBuilding(emptyBuilding(neighbor));
        }

        expect(manager.buildings.length, 2, reason: '因為3個都放置後入口會被擋住，所以成功放置的建築只會有2個');
      });
    });


  });

}
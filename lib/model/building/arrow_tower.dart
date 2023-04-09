import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

class ArrowTower extends BuildingModel {
  ArrowTower({required super.rotate, required super.location})
      : super(
    type: BuildingType.tower,
    cost: 10,
    damage: 1,
    range: 2,
  );

  ArrowTower.template()
      : this(
    rotate: 0,
    location: const BoardPoint(0, 0),
  );
}

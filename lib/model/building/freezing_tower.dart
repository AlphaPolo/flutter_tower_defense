
import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

class FreezingTower extends BuildingModel {
  FreezingTower({required super.rotate, required super.location})
      : super(
          type: BuildingType.tower,
          cost: 10,
          damage: 1,
          range: 2.2,
        );

  FreezingTower.template()
      : this(
          rotate: 0,
          location: const BoardPoint(0, 0),
        );
}

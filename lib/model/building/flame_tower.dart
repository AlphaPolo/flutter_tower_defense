
import '../../widget/game/board/board_painter.dart';
import 'building_model.dart';

class FlameTower extends BuildingModel {
  FlameTower({required super.rotate, required super.location})
      : super(
          type: BuildingType.tower,
          cost: 10,
          damage: 1,
          range: 2,
        );

  FlameTower.template()
      : this(
          rotate: 0,
          location: const BoardPoint(0, 0),
        );
}

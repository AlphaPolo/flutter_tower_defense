
import '../../widget/game/board/board_painter.dart';

enum BuildingType {
  tower,
  wall,
  trap,
}

class BuildingModel {

  final BuildingType type;
  final BoardPoint location;
  final int cost;
  final int damage;
  final double range;
  final int rotate;
  final double direction;

  const BuildingModel({
    required this.type,
    required this.location,
    required this.cost,
    required this.damage,
    required this.range,
    required this.rotate,
    this.direction = 0,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingModel &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          location == other.location &&
          cost == other.cost &&
          damage == other.damage &&
          range == other.range &&
          rotate == other.rotate &&
          direction == other.direction;

  @override
  int get hashCode =>
      type.hashCode ^
      location.hashCode ^
      cost.hashCode ^
      damage.hashCode ^
      range.hashCode ^
      rotate.hashCode ^
      direction.hashCode;
}



// class BuildingCostPreview {
//   int costMoney;
//   int cost;
// }
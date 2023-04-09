
import '../model/building/arrow_tower.dart';
import '../model/building/building_model.dart';
import '../model/building/canon_tower.dart';
import '../model/building/flame_tower.dart';
import '../model/building/freezing_tower.dart';

class BuildingProvider {

  final Map<BuildingModel, List> buildingTemplates = Map.unmodifiable({
    FreezingTower.template() : [],
    FlameTower.template() : [],
    ArrowTower.template() : [],
    CanonTower.template() : [],
  });


}
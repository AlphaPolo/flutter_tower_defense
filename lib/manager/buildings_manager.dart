
import 'dart:async';

import '../model/building/arrow_tower.dart';
import '../model/building/building_model.dart';
import '../model/building/canon_tower.dart';
import '../model/building/flame_tower.dart';
import '../model/building/freezing_tower.dart';
import 'game_manager.dart';

class BuildingsManager {

  late final GameManager gameManger;

  final Map<BuildingModel, List> buildingTemplates = Map.unmodifiable({
    FreezingTower.template() : [],
    FlameTower.template() : [],
    ArrowTower.template() : [],
    CanonTower.template() : [],
  });

  List<BuildingModel> buildings = [];

  final StreamController<List<BuildingModel>> _buildingsStreamController = StreamController();
  late final Stream<List<BuildingModel>> _buildingEvent = _buildingsStreamController.stream.asBroadcastStream();

  void tick(GameManager manager, int clock) {

  }

  void dispose() {
    _buildingsStreamController.close();
  }

  void init(GameManager manager) {
    gameManger = manager;
  }

  void addBuilding(BuildingModel model) {
    _buildingsStreamController.add(buildings);
  }

}
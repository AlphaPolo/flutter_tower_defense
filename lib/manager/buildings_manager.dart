
import 'dart:async';

import 'package:tower_defense/widget/game/board/board_painter.dart';

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
  Map<BoardPoint, BuildingModel> buildingsMap = {};

  final StreamController<List<BuildingModel>> _buildingsStreamController = StreamController();
  late final Stream<List<BuildingModel>> _buildingEvent = _buildingsStreamController.stream.asBroadcastStream();

  void tick(GameManager manager, int clock) {
    for (final building in buildings) {
      building.tick(gameManger, clock);
    }
  }

  void dispose() {
    _buildingsStreamController.close();
  }

  void init(GameManager manager) {
    gameManger = manager;
  }

  void addBuilding(BuildingModel model) {
    buildings.add(model);
    buildingsMap[model.location] = model;
    notifyListeners();
  }

  void notifyListeners() {
    _buildingsStreamController.add(buildings);
  }

  bool hasBuildingOn(BoardPoint point) => buildingsMap.containsKey(point);

  Stream<List<BuildingModel>> onBuildingsStream() => _buildingEvent;

}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/model/building/obstacle_tower.dart';
import 'package:tower_defense/widget/game/board/board_painter.dart';

import '../model/building/air_blade_tower.dart';
import '../model/building/building_model.dart';
import '../model/building/thunder_tower.dart';
import '../model/building/flame_tower.dart';
import '../model/building/freezing_tower.dart';
import '../r.g.dart';
import 'game_manager.dart';

class BuildingsManager {

  late final GameManager gameManger;

  final Map<BuildingModel, List> buildingTemplates = Map.unmodifiable({
    FreezingTower.template() : [
      Image(image: R.image.ice()),
      '冰凍塔',
      '傷害較低但能夠減緩周圍的敵人'
    ],
    FlameTower.template() : [
      Image(image: R.image.fire()),
      '火焰塔',
      '能夠噴射一直線的火焰，使其在直線範圍上的敵人受到持續地延燒傷害'
    ],
    AirBladeTower.template() : [
      Image(image: R.image.air()),
      '風刃塔',
      '能夠製造旋轉的風刃對周圍的敵人造成不錯的劈砍傷害'
    ],
    ThunderTower.template() : [
      Image(image: R.image.electricity()),
      '雷電塔',
      '能夠在敵人之間製造連鎖的電鏈一起受到電擊傷害，並有機率麻痺該敵人'
    ],

    ObstacleTower.template() : [
      const Icon(Icons.hexagon_outlined, color: Colors.brown, size: 64),
      '障礙物',
      '單純阻擋敵人前進的方向，沒有傷害敵人的行為'
    ],
  });

  List<BuildingModel> buildings = [];
  Map<BoardPoint, BuildingModel> buildingsMap = {};

  final StreamController<List<BuildingModel>> _buildingsStreamController = StreamController();
  late final Stream<List<BuildingModel>> _buildingEvent = _buildingsStreamController.stream.asBroadcastStream();

  void init(GameManager manager) {
    gameManger = manager;
  }

  void dispose() {
    _buildingsStreamController.close();
  }

  void tick(GameManager manager, int timeDelta) {
    for (final building in buildings) {
      if(building is ObstacleTower) continue;
      building.tick(gameManger, timeDelta);
    }
  }

  void addBuilding(BuildingModel model) {
    buildings.add(model);
    buildingsMap[model.location] = model;
    notifyListeners();
  }

  bool hasBuildingOn(BoardPoint point) => buildingsMap.containsKey(point);

  Stream<List<BuildingModel>> onBuildingsStream() => _buildingEvent;

  void notifyListeners() {
    _buildingsStreamController.add(buildings);
  }

}
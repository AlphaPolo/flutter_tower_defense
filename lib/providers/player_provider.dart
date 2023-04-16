import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';

import '../model/building/arrow_tower.dart';
import '../model/building/canon_tower.dart';
import '../model/building/flame_tower.dart';
import '../model/building/freezing_tower.dart';
import '../widget/game/board/board_painter.dart';
import 'game_event_provider.dart';

class PlayerProvider with ChangeNotifier {

  late final GameManager gameManager;
  // late final TimeLineSystem gameManager;
  late final StreamSubscription<BoardPoint?> _hoverListen;
  late final StreamSubscription<BoardPoint?> _selectedListen;
  late final StreamSubscription<BoardPoint?> _rightClickListen;
  late final StreamSubscription<BuildingModel?> _selectedBuildingListen;

  Completer? _completer;

  PlayerStatus status = const PlayerStatus(coin: 50, heart: 20);

  BuildingModel? selectingModel;


  PlayerProvider(BuildContext context) {
    final eventProvider = context.read<GameEventProvider>();
    gameManager = context.read<GameManager>();

    _hoverListen = eventProvider.onHoverStream().distinct().listen(_onHoverPoint);
    _selectedListen = eventProvider.onSelectedStream().listen(_onSelectedPoint);
    _rightClickListen = eventProvider.onRightClickStream().listen(_onRightClick);
    _selectedBuildingListen = eventProvider.onSelectedBuildingStream().listen(_onSelectedBuilding);
  }

  @override
  void dispose() {
    _hoverListen.cancel();
    _selectedListen.cancel();
    _rightClickListen.cancel();
    _selectedBuildingListen.cancel();
    super.dispose();
  }

  void _onHoverPoint(BoardPoint? point) {

  }


  void _onSelectedPoint(BoardPoint? point) {
    final model = selectingModel;
    if(point == null) return;

    if(model == null) {
      return;
    }

    print(point);
    placeBuilding(point, model);
    // selectingModel = null;
    notifyListeners();
  }

  void _onRightClick(BoardPoint? point) {
    if(selectingModel != null) {
      selectingModel = null;
      notifyListeners();
    }
  }

  /// 建造選單選擇的事件
  void _onSelectedBuilding(BuildingModel? model) {
    selectingModel = model;
    notifyListeners();
  }

  void placeBuilding(BoardPoint position, BuildingModel model) {
    switch(model.runtimeType) {
      case FlameTower: model = FlameTower(rotate: 0, location: position); break;
      case FreezingTower: model = FreezingTower(rotate: 0, location: position); break;
      case ArrowTower: model = ArrowTower(rotate: 0, location: position); break;
      case CanonTower: model = CanonTower(rotate: 0, location: position); break;
      default: break;
    }
    gameManager.addBuilding(model);
  }

}

class PlayerStatus {
  final int coin;
  final int heart;

  const PlayerStatus({
    required this.coin,
    required this.heart,
  });

  PlayerStatus copyWith({
    int? coin,
    int? heart,
  }) {
    return PlayerStatus(
      coin: coin ?? this.coin,
      heart: heart ?? this.heart,
    );
  }

  PlayerStatus add({
    int? coin,
    int? heart,
  }) {
    return copyWith(
      coin: coin?.let((x) => this.coin + x),
      heart: heart?.let((x) => this.heart + x),
    );
  }

  PlayerStatus sub({
    int? heart,
    int? coin,
  }) {
    return copyWith(
      coin: coin?.let((x) => this.coin - x),
      heart: heart?.let((x) => this.heart - x),
    );
  }
}
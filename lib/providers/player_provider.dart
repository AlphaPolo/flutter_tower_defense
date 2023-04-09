import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/building/building_model.dart';

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
      // gameManager.lookAt(point);
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
    gameManager.addBuilding(model.copyWith(location: position));
  }

}
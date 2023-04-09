import 'dart:async';

import '../model/building/building_model.dart';
import '../widget/game/board/board_painter.dart';


class GameEventProvider {
  final StreamController<BoardPoint?> _hoverController = StreamController();
  final StreamController<BoardPoint?> _selectedController = StreamController();
  final StreamController<BoardPoint?> _rightClickController = StreamController();
  final StreamController<BuildingModel?> _selectedBuildingController = StreamController();

  late final Stream<BoardPoint?> _hoverEvent = _hoverController.stream.asBroadcastStream();
  late final Stream<BoardPoint?> _selectedEvent = _selectedController.stream.asBroadcastStream();
  late final Stream<BoardPoint?> _rightClickEvent = _rightClickController.stream.asBroadcastStream();
  late final Stream<BuildingModel?> _selectedBuildingEvent = _selectedBuildingController.stream.asBroadcastStream();

  void dispose() {
    _hoverController.close();
    _selectedController.close();
    _rightClickController.close();
    _selectedBuildingController.close();
  }

  Stream<BoardPoint?> onHoverStream() => _hoverEvent;
  Stream<BoardPoint?> onSelectedStream() => _selectedEvent;
  Stream<BoardPoint?> onRightClickStream() => _rightClickEvent;
  Stream<BuildingModel?> onSelectedBuildingStream() => _selectedBuildingEvent;

  void pushHoverEvent(BoardPoint? event) {
    _hoverController.add(event);
  }

  void pushSelectedEvent(BoardPoint? event) {
    _selectedController.add(event);
  }

  void pushRightClickEvent(BoardPoint? event) {
    _rightClickController.add(event);
  }

  void pushSelectedBuildingEvent(BuildingModel? event) {
    _selectedBuildingController.add(event);
  }
}
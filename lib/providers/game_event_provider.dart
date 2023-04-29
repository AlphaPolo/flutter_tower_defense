import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/screens/my_app.dart';

import '../model/building/building_model.dart';
import '../model/enemy/enemy.dart';
import '../model/message/game_message.dart';
import '../widget/game/board/board_painter.dart';


class GameEventProvider {
  late final GameManager gameManager;

  final StreamController<Enemy> _enemyDeadController = StreamController();
  final StreamController<Enemy> _enemyGoalController = StreamController();
  final StreamController<BoardPoint?> _hoverController = StreamController();
  final StreamController<BoardPoint?> _selectedController = StreamController();
  final StreamController<BoardPoint?> _rightClickController = StreamController();
  final StreamController<BuildingModel?> _selectedBuildingController = StreamController();
  // final StreamController<GameMessage?> _messageController = StreamController();


  late final Stream<Enemy> _enemyDeadEvent = _enemyDeadController.stream.asBroadcastStream();
  late final Stream<Enemy> _enemyGoalEvent = _enemyGoalController.stream.asBroadcastStream();
  late final Stream<BoardPoint?> _hoverEvent = _hoverController.stream.asBroadcastStream();
  late final Stream<BoardPoint?> _selectedEvent = _selectedController.stream.asBroadcastStream();
  late final Stream<BoardPoint?> _rightClickEvent = _rightClickController.stream.asBroadcastStream();
  late final Stream<BuildingModel?> _selectedBuildingEvent = _selectedBuildingController.stream.asBroadcastStream();
  // late final Stream<GameMessage?> _messageEvent = _messageController.stream.asBroadcastStream();

  void dispose() {
    _enemyDeadController.close();
    _enemyGoalController.close();
    _hoverController.close();
    _selectedController.close();
    _rightClickController.close();
    _selectedBuildingController.close();
    // _messageController.close();
  }

  Stream<Enemy> onEnemyDeadStream() => _enemyDeadEvent;
  Stream<Enemy> onEnemyGoalStream() => _enemyGoalEvent;
  Stream<BoardPoint?> onHoverStream() => _hoverEvent;
  Stream<BoardPoint?> onSelectedStream() => _selectedEvent;
  Stream<BoardPoint?> onRightClickStream() => _rightClickEvent;
  Stream<BuildingModel?> onSelectedBuildingStream() => _selectedBuildingEvent;
  // Stream<GameMessage?> onMessageStream() => _messageEvent;

  void pushMessageEvent(GameMessage event) {
    scaffoldMessengerKey.currentState?.let((state) {
      state.clearSnackBars();
      state.showSnackBar(SnackBar(content: Text(event.message)));
    });
    // _messageController.add(message);
  }

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

  bool pushEnemyDeadEvent(Enemy event) {
    _enemyDeadController.add(event);
    return true;
  }

  bool pushEnemyArriveGoalEvent(Enemy event) {
    _enemyGoalController.add(event);
    return true;
  }

  void init(GameManager gameManager) {
    this.gameManager = gameManager;
  }
}
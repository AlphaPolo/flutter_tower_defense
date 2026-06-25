import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../board/hex.dart';
import '../tower_defense_game.dart';

/// 畫出 isometric 棋盤背景圖 + 出生點 / 終點 / hover 高亮，並處理輸入。
class BoardComponent extends PositionComponent
    with
        HasGameReference<TowerDefenseGame>,
        TapCallbacks,
        SecondaryTapCallbacks,
        PointerMoveCallbacks,
        DragCallbacks {
  BoardComponent() : super(priority: -2);

  BoardPoint? hovered;

  @override
  Future<void> onLoad() async {
    size = game.iso.imageSize.clone();
  }

  @override
  void render(Canvas canvas) {
    game.boardSprite.render(canvas, size: size);

    _highlight(canvas, game.targetLocation, Colors.green.withOpacity(0.45));
    _highlight(canvas, game.spawnLocation, Colors.red.withOpacity(0.45));
    final h = hovered;
    if (h != null) _highlight(canvas, h, Colors.orange.withOpacity(0.5));
  }

  void _highlight(Canvas canvas, BoardPoint bp, Color color) {
    final center = game.boardToLogical(bp);
    final r = game.board.hexagonRadius.toDouble();
    final pts = <Offset>[];
    for (final deg in const [-90, -30, 30, 90, 150, 210]) {
      final a = deg * pi / 180;
      final s = game.logicalToScreen(
        Vector2(center.x + r * cos(a), center.y + r * sin(a)),
      );
      pts.add(Offset(s.x, s.y));
    }
    canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = color);
  }

  // ── 輸入 ─────────────────────────────────────────────────
  @override
  void onTapUp(TapUpEvent event) {
    final bp = game.screenToBoard(event.localPosition);
    if (bp != null) game.tryPlaceAt(bp);
  }

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    game.cancelSelection();
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    hovered = game.screenToBoard(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.camera.viewfinder.position -= event.localDelta;
  }
}

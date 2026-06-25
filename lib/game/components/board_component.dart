import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../board/hex.dart';
import '../tower_defense_game.dart';

/// 畫出六角棋盤、出生點 / 終點 / 滑鼠停留的高亮，並處理所有輸入：
/// 點擊放塔、右鍵取消、滑鼠移動 hover、拖曳平移相機。
class BoardComponent extends PositionComponent
    with
        HasGameReference<TowerDefenseGame>,
        TapCallbacks,
        SecondaryTapCallbacks,
        PointerMoveCallbacks,
        DragCallbacks {
  BoardComponent() : super(priority: 0);

  BoardPoint? hovered;

  @override
  Future<void> onLoad() async {
    final s = game.board.size;
    size = Vector2(s.width, s.height);
  }

  // ── 繪製 ─────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    final board = game.board;

    for (final bp in board) {
      if (bp == null) continue;
      canvas.drawPath(
        _hexOutline(board.boardPointToOffset(bp)),
        Paint()..color = bp.color,
      );
    }

    _highlight(canvas, game.targetLocation, Colors.greenAccent.withOpacity(0.4));
    _highlight(canvas, game.spawnLocation, Colors.redAccent.withOpacity(0.4));
    final h = hovered;
    if (h != null) {
      _highlight(canvas, h, Colors.orange.withOpacity(0.5));
    }
  }

  void _highlight(Canvas canvas, BoardPoint bp, Color color) {
    canvas.drawPath(
      _hexOutline(game.board.boardPointToOffset(bp)),
      Paint()..color = color,
    );
  }

  Path _hexOutline(Offset center) {
    final p = game.board.positionsForHexagonAtOrigin;
    const idx = [0, 1, 2, 4, 6, 8];
    final path = Path();
    for (var i = 0; i < idx.length; i++) {
      final o = p[idx[i]].translate(center.dx, center.dy);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
  }

  // ── 輸入 ─────────────────────────────────────────────────
  BoardPoint? _toBoardPoint(Vector2 localPosition) =>
      game.board.pointToBoardPoint(Offset(localPosition.x, localPosition.y));

  @override
  void onTapUp(TapUpEvent event) {
    final bp = _toBoardPoint(event.localPosition);
    if (bp != null) game.tryPlaceAt(bp);
  }

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    game.cancelSelection();
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    hovered = _toBoardPoint(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.camera.viewfinder.position -= event.localDelta;
  }
}

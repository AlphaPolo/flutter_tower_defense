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

    _drawRoute(canvas);
    _highlight(canvas, game.targetLocation, Colors.green.withOpacity(0.45));
    _highlight(canvas, game.spawnLocation, Colors.red.withOpacity(0.45));
    final h = hovered;
    if (h != null) _highlight(canvas, h, Colors.orange.withOpacity(0.5));
  }

  /// 在地面畫出怪物行走路線（緞帶 + 方向箭頭）。
  void _drawRoute(Canvas canvas) {
    final route = game.route;
    if (route.length < 2) return;

    final s = game.iso.scaleX;
    final pts = [
      for (final bp in route)
        () {
          final v = game.boardToScreen(bp);
          return Offset(v.x, v.y);
        }()
    ];

    final ribbon = Paint()
      ..color = Colors.amber.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, ribbon);

    final arrow = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final d = b - a;
      final len = d.distance == 0 ? 1.0 : d.distance;
      final ux = d.dx / len, uy = d.dy / len;
      final sz = 7 * s;
      final tip = mid + Offset(ux * sz, uy * sz);
      // 兩條尾翼（垂直分量），組成箭頭 ">"
      final t1 = tip + Offset(-ux * sz - uy * sz, -uy * sz + ux * sz);
      final t2 = tip + Offset(-ux * sz + uy * sz, -uy * sz - ux * sz);
      canvas
        ..drawLine(tip, t1, arrow)
        ..drawLine(tip, t2, arrow);
    }
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

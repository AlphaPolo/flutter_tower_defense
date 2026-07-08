import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import '../board/hex.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

/// 畫出 isometric 棋盤背景圖 + 出生點 / 終點 / hover 高亮，並處理輸入。
class BoardComponent extends PositionComponent
    with
        HasGameReference<TowerDefenseGame>,
        TapCallbacks,
        SecondaryTapCallbacks,
        PointerMoveCallbacks {
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
    _highlight(canvas, game.targetLocation, Colors.greenAccent);
    _highlight(canvas, game.spawnLocation, Colors.redAccent);

    // 目前點選查看中的建築：青色框選，與 hover 區分；是塔就再畫貼地射程圈。
    final inspecting = game.inspecting.value;
    if (inspecting != null) {
      _rangeCircle(canvas, inspecting);
      _cornerFrame(canvas, inspecting, Colors.cyanAccent);
    }

    final h = hovered;
    if (h != null) {
      // 滑到建築/陷阱上→紅色(可拆除)；空地→橘色。用四角括號選取框。
      final removable = game.towers.containsKey(h) || game.traps.containsKey(h);
      _cornerFrame(
        canvas,
        h,
        removable ? Colors.redAccent : Colors.orangeAccent,
      );
    }
  }

  /// 點選查看的塔：畫出貼地的射程圓——邏輯半徑 = hexagonRadius × range，
  /// 與 enemiesInRange 的命中判定完全一致；逐點經 logicalToScreen 投影成
  /// 躺在地面角度上的橢圓。range<=0（障礙物）或該格非塔則不畫。
  void _rangeCircle(Canvas canvas, BoardPoint bp) {
    final tower = game.towers[bp];
    if (tower == null) return;
    // 滾木塔沿方向直線滾出、非圓形範圍（方向已有箭頭表示）→ 不畫圈。
    if (tower.type == TowerType.log) return;
    final range = tower.range; // 用塔的有效射程（含升級加成）
    if (range <= 0) return;
    final s = game.iso.scaleX;
    final center = game.boardToLogical(bp);
    final r = game.board.hexagonRadius * range;
    const steps = 48;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * pi;
      final p = game.logicalToScreen(
        Vector2(center.x + r * cos(a), center.y + r * sin(a)),
      );
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.cyanAccent.withValues(alpha: 0.07),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = Colors.cyanAccent.withValues(alpha: 0.55),
    );
  }

  /// 四角括號選取框：在六個頂點各畫一個 L 形角，邊中間留空（像對焦框）。
  void _cornerFrame(Canvas canvas, BoardPoint bp, Color color) {
    final pts = _hexPolygon(bp);
    final s = game.iso.scaleX;
    final path = Path()..addPolygon(pts, true);
    // 很淡的填色強調選取格
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));

    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    const f = 0.34; // 每個角往相鄰邊延伸的比例
    Offset lerp(Offset a, Offset b) =>
        Offset(a.dx + (b.dx - a.dx) * f, a.dy + (b.dy - a.dy) * f);
    for (var i = 0; i < pts.length; i++) {
      final v = pts[i];
      final prev = pts[(i - 1 + pts.length) % pts.length];
      final next = pts[(i + 1) % pts.length];
      canvas.drawPath(
        Path()
          ..moveTo(lerp(v, prev).dx, lerp(v, prev).dy)
          ..lineTo(v.dx, v.dy)
          ..lineTo(lerp(v, next).dx, lerp(v, next).dy),
        bracket,
      );
    }
  }

  /// 一格六角的螢幕座標頂點。[scale] 縮小可讓框線退到格子內側（不卡邊）。
  List<Offset> _hexPolygon(BoardPoint bp, {double scale = 0.9}) {
    final center = game.boardToLogical(bp);
    final r = game.board.hexagonRadius * scale;
    return [
      for (final deg in const [-90, -30, 30, 90, 150, 210])
        () {
          final a = deg * pi / 180;
          final s = game.logicalToScreen(
            Vector2(center.x + r * cos(a), center.y + r * sin(a)),
          );
          return Offset(s.x, s.y);
        }()
    ];
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

    final ribbon = _ribbonPaint..strokeWidth = 14 * s;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, ribbon);

    final arrow = _arrowPaint..strokeWidth = 2.5 * s;
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

  // 每幀重用的 paint（顏色/線寬每次呼叫改設定，不重新配置物件）。
  static final Paint _ribbonPaint = Paint()
    ..color = Colors.amber.withValues(alpha: 0.45)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  static final Paint _arrowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _hlFillPaint = Paint();
  static final Paint _hlStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;

  /// 框選樣式：淡填色 + 外框線。[frame] 為 true 時框更亮更粗（hover 用）。
  void _highlight(Canvas canvas, BoardPoint bp, Color color,
      {bool frame = false}) {
    final s = game.iso.scaleX;
    final path = Path()..addPolygon(_hexPolygon(bp), true);
    _hlFillPaint.color = color.withValues(alpha: frame ? 0.12 : 0.22);
    canvas.drawPath(path, _hlFillPaint);
    _hlStrokePaint
      ..strokeWidth = (frame ? 3.5 : 2.2) * s
      ..color = color.withValues(alpha: frame ? 1.0 : 0.85);
    canvas.drawPath(path, _hlStrokePaint);
  }

  // ── 輸入 ─────────────────────────────────────────────────
  @override
  void onTapUp(TapUpEvent event) {
    final bp = game.screenToBoard(event.localPosition);
    if (bp == null) {
      game.cancelSelection(); // 點到棋盤透明角落 → 取消（同右鍵）
      return;
    }
    if (game.isInspectable(bp)) {
      // 點到建築 / 陷阱 / 主堡 / 出生點 → 顯示該格資訊（並取消正在選的塔）。
      game.inspectAt(bp);
    } else {
      // 空地 → 關閉資訊面板，嘗試蓋目前選取的塔。
      game.inspecting.value = null;
      game.tryPlaceAt(bp);
    }
  }

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) {
    // 右鍵：取消目前選取要蓋的建築 / 關閉資訊面板。
    game.cancelSelection();
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    hovered = game.screenToBoard(event.localPosition);
  }
}

/// 覆蓋整個視野、畫在最底層的點擊接收器：點到棋盤外（黑色空白）→ 取消（同右鍵）。
class BackgroundTapCatcher extends PositionComponent
    with HasGameReference<TowerDefenseGame>, TapCallbacks {
  BackgroundTapCatcher() : super(priority: -100);

  @override
  Future<void> onLoad() async {
    size = Vector2.all(200000);
    position = game.iso.imageSize / 2 - size / 2; // 以棋盤為中心覆蓋整個視野
  }

  @override
  void onTapUp(TapUpEvent event) {
    // localPosition 轉回世界座標再判斷；非格子 → 取消。
    final world = position + event.localPosition;
    if (game.screenToBoard(world) == null) game.cancelSelection();
  }
}

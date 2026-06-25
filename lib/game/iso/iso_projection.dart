import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../board/hex.dart';

/// Maps the game's top-down "logical" coordinates to isometric screen
/// coordinates (the pre-rendered board's pixel space) and back.
///
/// Game logic (movement, ranges, targeting) stays entirely in logical space;
/// this is only used to place sprites for rendering.
class IsoProjection {
  IsoProjection._(
    this.imageSize,
    this.cellScreen,
    this._a,
    this._b,
    this._c,
    this._d,
    this._e,
    this._f,
    this._ia,
    this._ib,
    this._ic,
    this._id,
    this._ie,
    this._if,
    this.scaleX,
    this.scaleY,
  );

  /// Pixel size of the rendered board image (world space for rendering).
  final Vector2 imageSize;

  /// Screen (board-pixel) position of every cell's tile-top centre.
  final Map<BoardPoint, Vector2> cellScreen;

  // logical -> screen : sx = a*lx + b*ly + c ; sy = d*lx + e*ly + f
  final double _a, _b, _c, _d, _e, _f;
  // inverse (screen -> logical)
  final double _ia, _ib, _ic, _id, _ie, _if;

  /// Screen pixels per logical unit along logical X / Y (for sizing sprites).
  final double scaleX;
  final double scaleY;

  static IsoProjection fromJson(String jsonStr, Board board) {
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    final res = j['res'] as List;
    final imageSize =
        Vector2((res[0] as num).toDouble(), (res[1] as num).toDouble());

    final cellScreen = <BoardPoint, Vector2>{};
    for (final c in (j['cells'] as List)) {
      final m = c as Map<String, dynamic>;
      cellScreen[BoardPoint(m['q'] as int, m['r'] as int)] =
          Vector2((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
    }

    // Fit the exact affine from three non-collinear cells.
    Offset l(int q, int r) => board.boardPointToOffset(BoardPoint(q, r));
    Vector2 s(int q, int r) => cellScreen[BoardPoint(q, r)]!;
    final l0 = l(0, 0), l1 = l(1, 0), l2 = l(0, 1);
    final s0 = s(0, 0), s1 = s(1, 0), s2 = s(0, 1);

    final dl1x = l1.dx - l0.dx, dl1y = l1.dy - l0.dy;
    final dl2x = l2.dx - l0.dx, dl2y = l2.dy - l0.dy;
    final det = dl1x * dl2y - dl1y * dl2x;

    double coefA(double d1, double d2) => (d1 * dl2y - d2 * dl1y) / det;
    double coefB(double d1, double d2) => (dl1x * d2 - dl2x * d1) / det;

    final a = coefA(s1.x - s0.x, s2.x - s0.x);
    final b = coefB(s1.x - s0.x, s2.x - s0.x);
    final c = s0.x - a * l0.dx - b * l0.dy;
    final d = coefA(s1.y - s0.y, s2.y - s0.y);
    final e = coefB(s1.y - s0.y, s2.y - s0.y);
    final f = s0.y - d * l0.dx - e * l0.dy;

    final idet = a * e - b * d;
    final ia = e / idet, ib = -b / idet, id = -d / idet, ie = a / idet;
    final ic = -(ia * c + ib * f);
    final ifc = -(id * c + ie * f);

    final scaleX = sqrt(a * a + d * d);
    final scaleY = sqrt(b * b + e * e);

    return IsoProjection._(
      imageSize, cellScreen, a, b, c, d, e, f, ia, ib, ic, id, ie, ifc,
      scaleX, scaleY,
    );
  }

  Vector2 logicalToScreen(Vector2 p) =>
      Vector2(_a * p.x + _b * p.y + _c, _d * p.x + _e * p.y + _f);

  Vector2 screenToLogical(Vector2 p) =>
      Vector2(_ia * p.x + _ib * p.y + _ic, _id * p.x + _ie * p.y + _if);
}

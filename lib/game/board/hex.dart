import 'dart:collection' show IterableMixin;
import 'dart:math';
import 'dart:ui' show Vertices;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// 六角格的六個方向（axial coordinates）。
enum HexagonDirection {
  nw,
  ne,
  e,
  se,
  sw,
  w;

  HexagonDirection get opposite {
    switch (this) {
      case HexagonDirection.nw:
        return HexagonDirection.se;
      case HexagonDirection.ne:
        return HexagonDirection.sw;
      case HexagonDirection.e:
        return HexagonDirection.w;
      case HexagonDirection.se:
        return HexagonDirection.nw;
      case HexagonDirection.sw:
        return HexagonDirection.ne;
      case HexagonDirection.w:
        return HexagonDirection.e;
    }
  }

  double get degree {
    switch (this) {
      case HexagonDirection.nw:
        return 240;
      case HexagonDirection.ne:
        return 300;
      case HexagonDirection.e:
        return 0;
      case HexagonDirection.se:
        return 60;
      case HexagonDirection.sw:
        return 120;
      case HexagonDirection.w:
        return 180;
    }
  }
}

/// 整個六角棋盤的狀態與座標換算工具。Iterable 讓所有 BoardPoint 都能被走訪。
@immutable
class Board extends Object with IterableMixin<BoardPoint?> {
  Board({
    required this.boardRadius,
    required this.hexagonRadius,
    required this.hexagonMargin,
    this.selected,
    List<BoardPoint>? boardPoints,
  })  : assert(boardRadius > 0),
        assert(hexagonRadius > 0),
        assert(hexagonMargin >= 0) {
    final hexStart = Point<double>(0, -hexagonRadius);
    final hexagonRadiusPadded = hexagonRadius - hexagonMargin;
    final centerToFlat = sqrt(3) / 2 * hexagonRadiusPadded;
    positionsForHexagonAtOrigin.addAll(<Offset>[
      Offset(hexStart.x, hexStart.y),
      Offset(hexStart.x + centerToFlat, hexStart.y + 0.5 * hexagonRadiusPadded),
      Offset(hexStart.x + centerToFlat, hexStart.y + 1.5 * hexagonRadiusPadded),
      Offset(hexStart.x + centerToFlat, hexStart.y + 1.5 * hexagonRadiusPadded),
      Offset(hexStart.x, hexStart.y + 2 * hexagonRadiusPadded),
      Offset(hexStart.x, hexStart.y + 2 * hexagonRadiusPadded),
      Offset(hexStart.x - centerToFlat, hexStart.y + 1.5 * hexagonRadiusPadded),
      Offset(hexStart.x - centerToFlat, hexStart.y + 1.5 * hexagonRadiusPadded),
      Offset(hexStart.x - centerToFlat, hexStart.y + 0.5 * hexagonRadiusPadded),
    ]);

    if (boardPoints != null) {
      _boardPoints.addAll(boardPoints);
    } else {
      var boardPoint = _getNextBoardPoint(null);
      while (boardPoint != null) {
        _boardPoints.add(boardPoint);
        boardPoint = _getNextBoardPoint(boardPoint);
      }
    }
  }

  final int boardRadius; // Number of hexagons from center to edge.
  final double hexagonRadius; // Pixel radius of a hexagon (center to vertex).
  final double hexagonMargin; // Margin between hexagons.
  final List<Offset> positionsForHexagonAtOrigin = <Offset>[];
  final BoardPoint? selected;
  final List<BoardPoint> _boardPoints = <BoardPoint>[];

  @override
  Iterator<BoardPoint?> get iterator => _BoardIterator(_boardPoints);

  _Range _getRRangeForQ(int q) {
    int rStart;
    int rEnd;
    if (q <= 0) {
      rStart = -boardRadius - q;
      rEnd = boardRadius;
    } else {
      rEnd = boardRadius - q;
      rStart = -boardRadius;
    }

    return _Range(rStart, rEnd);
  }

  BoardPoint? _getNextBoardPoint(BoardPoint? boardPoint) {
    if (boardPoint == null) {
      return BoardPoint(-boardRadius, 0);
    }

    final rRange = _getRRangeForQ(boardPoint.q);

    if (boardPoint.q >= boardRadius && boardPoint.r >= rRange.max) {
      return null;
    }

    if (boardPoint.r >= rRange.max) {
      return BoardPoint(boardPoint.q + 1, _getRRangeForQ(boardPoint.q + 1).min);
    }

    return BoardPoint(boardPoint.q, boardPoint.r + 1);
  }

  bool validateBoardPoint(BoardPoint boardPoint) {
    const center = BoardPoint(0, 0);
    final distanceFromCenter = getDistance(center, boardPoint);
    return distanceFromCenter <= boardRadius;
  }

  Size get size {
    final centerToFlat = sqrt(3) / 2 * hexagonRadius;
    return Size(
      (boardRadius * 2 + 1) * centerToFlat * 2,
      2 * (hexagonRadius + boardRadius * 1.5 * hexagonRadius),
    );
  }

  static int getDistance(BoardPoint a, BoardPoint b) {
    final a3 = a.cubeCoordinates;
    final b3 = b.cubeCoordinates;
    return ((a3.x - b3.x).abs() + (a3.y - b3.y).abs() + (a3.z - b3.z).abs()) ~/
        2;
  }

  BoardPoint? pointToBoardPoint(Offset point) {
    final pointCentered = Offset(
      point.dx - size.width / 2,
      point.dy - size.height / 2,
    );
    final boardPoint = BoardPoint(
      ((sqrt(3) / 3 * pointCentered.dx - 1 / 3 * pointCentered.dy) /
              hexagonRadius)
          .round(),
      ((2 / 3 * pointCentered.dy) / hexagonRadius).round(),
    );

    if (!validateBoardPoint(boardPoint)) {
      return null;
    }

    return _boardPoints.firstWhere((boardPointI) {
      return boardPointI.q == boardPoint.q && boardPointI.r == boardPoint.r;
    });
  }

  Point<double> boardPointToPoint(BoardPoint boardPoint) {
    return Point<double>(
      sqrt(3) * hexagonRadius * boardPoint.q +
          sqrt(3) / 2 * hexagonRadius * boardPoint.r +
          size.width / 2,
      1.5 * hexagonRadius * boardPoint.r + size.height / 2,
    );
  }

  /// 直接給出 BoardPoint 中心點的 Offset（場景座標）。
  Offset boardPointToOffset(BoardPoint boardPoint) {
    final point = boardPointToPoint(boardPoint);
    return Offset(point.x, point.y);
  }

  Vertices getVerticesForBoardPoint(BoardPoint boardPoint, Color color) {
    final centerOfHexZeroCenter = boardPointToPoint(boardPoint);

    final positions = positionsForHexagonAtOrigin.map((offset) {
      return offset.translate(centerOfHexZeroCenter.x, centerOfHexZeroCenter.y);
    }).toList();

    return Vertices(
      VertexMode.triangleFan,
      positions,
      colors: List<Color>.filled(positions.length, color),
    );
  }
}

class _BoardIterator implements Iterator<BoardPoint?> {
  _BoardIterator(this.boardPoints);

  final List<BoardPoint> boardPoints;
  int? currentIndex;

  @override
  BoardPoint? current;

  @override
  bool moveNext() {
    if (currentIndex == null) {
      currentIndex = 0;
    } else {
      currentIndex = currentIndex! + 1;
    }

    if (currentIndex! >= boardPoints.length) {
      current = null;
      return false;
    }

    current = boardPoints[currentIndex!];
    return true;
  }
}

@immutable
class _Range {
  const _Range(this.min, this.max) : assert(min <= max);

  final int min;
  final int max;
}

/// 棋盤上的一個位置（axial coordinates）。
/// https://www.redblobgames.com/grids/hexagons/#coordinates-axial
@immutable
class BoardPoint {
  const BoardPoint(
    this.q,
    this.r, {
    this.color = const Color(0xFFCDCDCD),
  });

  final int q;
  final int r;
  final Color color;

  @override
  String toString() => 'BoardPoint($q, $r)';

  @override
  bool operator ==(Object other) {
    return other is BoardPoint && other.q == q && other.r == r;
  }

  @override
  int get hashCode => Object.hash(q, r);

  BoardPoint copyWithColor(Color nextColor) =>
      BoardPoint(q, r, color: nextColor);

  Vector3 get cubeCoordinates {
    return Vector3(
      q.toDouble(),
      r.toDouble(),
      (-q - r).toDouble(),
    );
  }

  List<BoardPoint> getNeighbors() {
    return [
      BoardPoint(q, r - 1),
      BoardPoint(q + 1, r - 1),
      BoardPoint(q + 1, r),
      BoardPoint(q, r + 1),
      BoardPoint(q - 1, r + 1),
      BoardPoint(q - 1, r),
    ];
  }

  BoardPoint getNeighbor(HexagonDirection direction) {
    switch (direction) {
      case HexagonDirection.nw:
        return BoardPoint(q, r - 1);
      case HexagonDirection.ne:
        return BoardPoint(q + 1, r - 1);
      case HexagonDirection.e:
        return BoardPoint(q + 1, r);
      case HexagonDirection.se:
        return BoardPoint(q, r + 1);
      case HexagonDirection.sw:
        return BoardPoint(q - 1, r + 1);
      case HexagonDirection.w:
        return BoardPoint(q - 1, r);
    }
  }
}

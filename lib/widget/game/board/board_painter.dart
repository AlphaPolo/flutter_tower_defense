import 'dart:collection' show IterableMixin;
import 'dart:math';
import 'dart:ui' show Vertices;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

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

// CustomPainter is what is passed to CustomPaint and actually draws the scene
// when its `paint` method is called.
class BoardPainter extends CustomPainter {
  const BoardPainter({required this.board});

  final Board board;

  @override
  void paint(Canvas canvas, Size size) {
    // print('board repaint');
    void drawBoardPoint(BoardPoint? boardPoint) {
      final color = boardPoint!.color.withOpacity(
        board.selected == boardPoint ? 0.7 : 1,
      );
      final vertices = board.getVerticesForBoardPoint(boardPoint, color);
      canvas.drawVertices(vertices, BlendMode.color, Paint());
    }

    board.forEach(drawBoardPoint);
  }

  // We should repaint whenever the board changes, such as board.selected.
  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    return oldDelegate.board != board;
  }
}
// BEGIN transformationsDemo#2

// The entire state of the hex board and abstraction to get information about
// it. Iterable so that all BoardPoints on the board can be iterated over.
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
    // Set up the positions for the center hexagon where the entire board is
    // centered on the origin.
    // Start point of hexagon (top vertex).
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
      // Generate boardPoints for a fresh board.
      var boardPoint = _getNextBoardPoint(null);
      while (boardPoint != null) {
        _boardPoints.add(boardPoint);
        boardPoint = _getNextBoardPoint(boardPoint);
      }
      /// DEBUG
      // print(_boardPoints.splitBetween(
      //         (first, second) => first.q < second.q)
      //     .map((list) => list.map((e) => '[q: ${e.q}, r: ${e.r}]').join(','))
      //     .join('\n')
      // );

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

  // For a given q axial coordinate, get the range of possible r values
  // See the definition of BoardPoint for more information about hex grids and
  // axial coordinates.
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

  // Get the BoardPoint that comes after the given BoardPoint. If given null,
  // returns the origin BoardPoint. If given BoardPoint is the last, returns
  // null.
  BoardPoint? _getNextBoardPoint(BoardPoint? boardPoint) {
    // If before the first element.
    if (boardPoint == null) {
      return BoardPoint(-boardRadius, 0);
    }

    final rRange = _getRRangeForQ(boardPoint.q);

    // If at or after the last element.
    if (boardPoint.q >= boardRadius && boardPoint.r >= rRange.max) {
      return null;
    }

    // If wrapping from one q to the next.
    if (boardPoint.r >= rRange.max) {
      return BoardPoint(boardPoint.q + 1, _getRRangeForQ(boardPoint.q + 1).min);
    }

    // Otherwise we're just incrementing r.
    return BoardPoint(boardPoint.q, boardPoint.r + 1);
  }

  // Check if the board point is actually on the board.
  bool validateBoardPoint(BoardPoint boardPoint) {
    const center = BoardPoint(0, 0);
    final distanceFromCenter = getDistance(center, boardPoint);
    return distanceFromCenter <= boardRadius;
  }

  // Get the size in pixels of the entire board.
  Size get size {
    final centerToFlat = sqrt(3) / 2 * hexagonRadius;
    return Size(
      (boardRadius * 2 + 1) * centerToFlat * 2,
      2 * (hexagonRadius + boardRadius * 1.5 * hexagonRadius),
    );
  }

  // Get the distance between two BoardPoints.
  static int getDistance(BoardPoint a, BoardPoint b) {
    final a3 = a.cubeCoordinates;
    final b3 = b.cubeCoordinates;
    return ((a3.x - b3.x).abs() + (a3.y - b3.y).abs() + (a3.z - b3.z).abs()) ~/
        2;
  }

  // Return the q,r BoardPoint for a point in the scene, where the origin is in
  // the center of the board in both coordinate systems. If no BoardPoint at the
  // location, return null.
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

  // Return a scene point for the center of a hexagon given its q,r point.
  Point<double> boardPointToPoint(BoardPoint boardPoint) {
    return Point<double>(
      sqrt(3) * hexagonRadius * boardPoint.q +
          sqrt(3) / 2 * hexagonRadius * boardPoint.r +
          size.width / 2,
      1.5 * hexagonRadius * boardPoint.r + size.height / 2,
    );
  }

  // Get Vertices that can be drawn to a Canvas for the given BoardPoint.
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

  // Return a new board with the given BoardPoint selected.
  Board copyWithSelected(BoardPoint? boardPoint) {
    if (selected == boardPoint) {
      return this;
    }
    final nextBoard = Board(
      boardRadius: boardRadius,
      hexagonRadius: hexagonRadius,
      hexagonMargin: hexagonMargin,
      selected: boardPoint,
      boardPoints: _boardPoints,
    );
    return nextBoard;
  }

  // Return a new board where boardPoint has the given color.
  Board copyWithBoardPointColor(BoardPoint boardPoint, Color color) {
    final nextBoardPoint = boardPoint.copyWithColor(color);
    final boardPointIndex = _boardPoints.indexWhere((boardPointI) =>
    boardPointI.q == boardPoint.q && boardPointI.r == boardPoint.r);

    if (elementAt(boardPointIndex) == boardPoint && boardPoint.color == color) {
      return this;
    }

    final nextBoardPoints = List<BoardPoint>.from(_boardPoints);
    nextBoardPoints[boardPointIndex] = nextBoardPoint;
    final selectedBoardPoint =
    boardPoint == selected ? nextBoardPoint : selected;
    return Board(
      boardRadius: boardRadius,
      hexagonRadius: hexagonRadius,
      hexagonMargin: hexagonMargin,
      selected: selectedBoardPoint,
      boardPoints: nextBoardPoints,
    );
  }

  int compareQ(BoardPoint a, BoardPoint b) => a.q.compareTo(b.q);
  int compareR(BoardPoint a, BoardPoint b) => a.r.compareTo(b.r);
  // final combine = compareQ.then(compareR);
  // print('isSorted: ${_boardPoints.isSorted(combine)}');
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

// A range of q/r board coordinate values.
@immutable
class _Range {
  const _Range(this.min, this.max) : assert(min <= max);

  final int min;
  final int max;
}

// A location on the board in axial coordinates.
// Axial coordinates use two integers, q and r, to locate a hexagon on a grid.
// https://www.redblobgames.com/grids/hexagons/#coordinates-axial
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
  String toString() {
    return 'BoardPoint($q, $r, $color)';
  }

  // Only compares by location.
  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is BoardPoint && other.q == q && other.r == r;
  }

  @override
  int get hashCode => Object.hash(q, r);

  BoardPoint copyWithColor(Color nextColor) =>
      BoardPoint(q, r, color: nextColor);

  // Convert from q,r axial coords to x,y,z cube coords.
  Vector3 get cubeCoordinates {
    return Vector3(
      q.toDouble(),
      r.toDouble(),
      (-q - r).toDouble(),
    );
  }

  List<BoardPoint> getNeighbors() {
    return [
      BoardPoint(q, r-1),
      BoardPoint(q+1, r-1),
      BoardPoint(q+1, r),
      BoardPoint(q, r+1),
      BoardPoint(q-1, r+1),
      BoardPoint(q-1, r),
    ];
  }

  BoardPoint getNeighbor(HexagonDirection direction) {
    switch(direction) {
      case HexagonDirection.nw: return BoardPoint(q, r-1);
      case HexagonDirection.ne: return BoardPoint(q+1, r-1);
      case HexagonDirection.e: return BoardPoint(q+1, r);
      case HexagonDirection.se: return BoardPoint(q, r+1);
      case HexagonDirection.sw: return BoardPoint(q-1, r+1);
      case HexagonDirection.w: return BoardPoint(q-1, r);
    }
  }
}


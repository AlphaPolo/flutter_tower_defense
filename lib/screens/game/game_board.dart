import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/gestures/events.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/constant/game_constant.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/widget/game/building/tower_widget.dart';
import 'package:tower_defense/widget/game/character/enemy_widget.dart';
import 'package:tuple/tuple.dart';

import '../../model/enemy/enemy.dart';
import '../../providers/game_event_provider.dart';
import '../../widget/game/board/board_painter.dart';
import '../../widget/game/board/hexagon_widget.dart';
import '../../widget/game/edit_board_point.dart';
// BEGIN transformationsDemo#1

const initPosition = BoardPoint(_GameBoardState._kBoardRadius, -_GameBoardState._kBoardRadius);

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late final GameEventProvider gameEventManager;
  late final GameManager gameManager;

  final GlobalKey _targetKey = GlobalKey();

  // The radius of a hexagon tile in pixels.
  static const _kHexagonRadius = 32.0;

  // The margin between hexagons.
  static const _kHexagonMargin = 4.0;


  // The radius of the entire board in hexagons, not including the center.
  static const _kBoardRadius = 5;

  final ValueNotifier<Tuple2<Offset, Offset>?> bow = ValueNotifier(null);
  final ValueNotifier<Offset?> movement = ValueNotifier(null);

  Board _board = Board(
    boardRadius: _kBoardRadius,
    hexagonRadius: _kHexagonRadius,
    hexagonMargin: _kHexagonMargin,
  );

  final TransformationController _transformationController = TransformationController();
  Animation<Matrix4>? _animationReset;
  late AnimationController _controllerReset;
  Matrix4? _homeMatrix;

  late var ballPosition;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('setting');
    gameEventManager = context.read<GameEventProvider>();
    gameManager = context.read<GameManager>();

    /// 左上與右下分別為主堡與怪物出生點
    gameManager.board = _board;
    gameManager.targetLocation = const BoardPoint(0, -_kBoardRadius);
    gameManager.spawnLocation = const BoardPoint(0, _kBoardRadius);
  }

  // Handle reset to home transform animation.
  void _onAnimateReset() {
    _transformationController.value = _animationReset!.value;
    if (!_controllerReset.isAnimating) {
      _animationReset?.removeListener(_onAnimateReset);
      _animationReset = null;
      _controllerReset.reset();
    }
  }

  // Initialize the reset to home transform animation.
  void _animateResetInitialize() {
    _controllerReset.reset();
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: _homeMatrix,
    ).animate(CurvedAnimation(parent: _controllerReset, curve: Curves.easeInOutCubicEmphasized));
    _controllerReset.duration = const Duration(milliseconds: 500);
    _animationReset!.addListener(_onAnimateReset);
    _controllerReset.forward();
  }

  // Stop a running reset to home transform animation.
  void _animateResetStop() {
    _controllerReset.stop();
    _animationReset?.removeListener(_onAnimateReset);
    _animationReset = null;
    _controllerReset.reset();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if(bow.value != null) return;
    // If the user tries to cause a transformation while the reset animation is
    // running, cancel the reset animation.
    if (_controllerReset.status == AnimationStatus.forward) {
      _animateResetStop();
    }
  }

  void _onTapUp(TapUpDetails details) {

    final offset = details.localPosition;
    final scenePoint = _transformationController.toScene(offset);
    final boardPoint = _board.pointToBoardPoint(scenePoint);

    gameEventManager.pushSelectedEvent(boardPoint);

    // /// place Ball
    // final point = boardPoint?.let(_board.boardPointToPoint);
    // setState(() {
    //   _board = _board.copyWithSelected(boardPoint);
    //   ballPosition.value = point;
    //   print(boardPoint);
    // });
  }

  void _onSecondaryTapUp(TapUpDetails details) {

    final offset = details.localPosition;
    final scenePoint = _transformationController.toScene(offset);
    final boardPoint = _board.pointToBoardPoint(scenePoint);

    gameEventManager.pushRightClickEvent(boardPoint);
  }

  void _onHover(PointerHoverEvent event) {
    final offset = event.localPosition;
    final scenePoint = _transformationController.toScene(offset);
    final boardPoint = _board.pointToBoardPoint(scenePoint);

    gameEventManager.pushHoverEvent(boardPoint);

    /// FIXME calc center point
    // final centerPoint = boardPoint == null ? null : _board.boardPointToPoint(boardPoint);
    // ghostPosition.value = centerPoint;
  }

  @override
  void initState() {
    super.initState();
    _controllerReset = AnimationController(
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controllerReset.dispose();
    _transformationController.dispose();
    bow.dispose();
    movement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('gameboard rebuild');
    // The scene is drawn by a CustomPaint, but user interaction is handled by
    // the InteractiveViewer parent widget.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Draw the scene as big as is available, but allow the user to
        // translate beyond that to a visibleSize that's a bit bigger.
        final viewportSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        // Start the first render, start the scene centered in the viewport.
        if (_homeMatrix == null) {
          _homeMatrix = Matrix4.identity()
            ..translate(
              viewportSize.width / 2 - _board.size.width / 2,
              viewportSize.height / 2 - _board.size.height / 2,
            );
          _transformationController.value = _homeMatrix!;
        }

        return ClipRect(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onHover: _onHover,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _onTapUp,
              onSecondaryTapUp: _onSecondaryTapUp,
              child: InteractiveViewer(
                key: _targetKey,
                transformationController: _transformationController,
                boundaryMargin: EdgeInsets.symmetric(
                  horizontal: viewportSize.width,
                  vertical: viewportSize.height,
                ),
                minScale: 0.01,
                scaleEnabled: bow.value == null,
                onInteractionStart: _onScaleStart,
                child: SizedBox.expand(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      boardBackground(),
                      ...locationIndicator(),
                      towerBuildings(),
                      if(gameDebug)
                      guideIndicator(),
                      hoverIndicator(),
                      buildEnemies(),
                      // drawUnits(),
                      // ball(),
                      // buildEnemy(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  RepaintBoundary boardBackground() {
    return RepaintBoundary(
      child: CustomPaint(
        size: _board.size,
        painter: BoardPainter(
          board: _board,
        ),
      ),
    );
  }


  IconButton get resetButton {
    return IconButton(
      onPressed: () {
        setState(() {
          _animateResetInitialize();
        });
      },
      tooltip: 'Reset',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.replay),
    );
  }

  IconButton get editButton {
    return IconButton(
      onPressed: () {
        if (_board.selected == null) {
          return;
        }
        showModalBottomSheet<Widget>(
            context: context,
            builder: (context) {
              return Container(
                width: double.infinity,
                height: 150,
                padding: const EdgeInsets.all(12),
                child: EditBoardPoint(
                  boardPoint: _board.selected!,
                  onColorSelection: (color) {
                    setState(() {
                      _board = _board.copyWithBoardPointColor(_board.selected!, color);
                      Navigator.pop(context);
                    });
                  },
                ),
              );
            });
      },
      tooltip: 'Edit',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.edit),
    );
  }


  Widget ball() {
    return ValueListenableBuilder<Point<double>?>(
      valueListenable: ballPosition,
      builder: (context, position, _) {
        if(position == null) return const SizedBox.shrink();
        return AnimatedPositioned.fromRect(
          rect: Rect.fromCircle(center: Offset(position.x, position.y - _kHexagonMargin), radius: 10),
          duration: movement.value != null ? 0.ms : 700.ms,
          curve: movement.value != null ? Curves.linear : Curves.easeInOutCubicEmphasized,
          // curve: SpringCurve(a: 0.1, w: 15),
          child: _!,
        );
      },
      child: GestureDetector(
        // onPanStart: (event) {
        //   setState(() {
        //     bow.value = Tuple2(event.localPosition, event.localPosition);
        //   });
        // },
        // onPanUpdate: (event) {
        //   bow.value = bow.value?.withItem2(event.localPosition);
        //   final value = bow.value;
        //   if(value != null) {
        //     final to = value.item1 - value.item2;
        //     final lineLength = (to.distance * 0.8).clamp(0, 2.5 * _kHexagonRadius).toDouble();
        //
        //     const eachCost = (2.5 * _kHexagonRadius) / 3;
        //     final cost = (lineLength / eachCost).ceil();
        //
        //     context.read<PlayerProvider>().costTime = cost;
        //   }
        // },
        // onPanCancel: () {
        //   print("cancel");
        //   setState(() {
        //     bow.value = null;
        //     final provider = context.read<PlayerProvider>();
        //     provider.costTime = 0;
        //   });
        // },
        // onPanEnd: (_) {
        //   setState(() {
        //     shoot();
        //     bow.value = null;
        //     final clockProvider = context.read<TimeLineSystem>();
        //     final provider = context.read<PlayerProvider>();
        //     clockProvider.clock += provider.costTime ?? 0;
        //     provider.costTime = 0;
        //   });
        // },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

  }

  Widget hoverIndicator() {

    return StreamBuilder<Point<double>?>(
      stream: gameEventManager.onHoverStream().distinct().map((boardPoint) => boardPoint?.let(_board.boardPointToPoint)),
      builder: (context, snapshot) {
        final point = snapshot.data;
        if(point == null) return const SizedBox.shrink();

        return AnimatedPositioned.fromRect(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutQuart,
          rect: Rect.fromCircle(center: Offset(point.x, point.y - _kHexagonMargin), radius: _kHexagonRadius),
          child: Padding(
            padding: const EdgeInsets.all(_kHexagonMargin),
            child: Stack(
              children: [
                HexagonWidget(color: Colors.orange.withOpacity(0.5)),
                // OverflowBox(
                //   maxWidth: _kHexagonRadius * 5,
                //   maxHeight: _kHexagonRadius * 5,
                //   child: Container(
                //     decoration: const BoxDecoration(
                //       shape: BoxShape.circle,
                //       gradient: RadialGradient(
                //         colors: [Colors.transparent, Colors.black],
                //         stops: [0.92, 1.0],
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );

  }

  List<Widget> locationIndicator() {
    final target = _board.boardPointToPoint(gameManager.targetLocation!);
    final spawn = _board.boardPointToPoint(gameManager.spawnLocation!);
    return [
      Positioned.fromRect(
        // duration: const Duration(milliseconds: 100),
        // curve: Curves.easeOutQuart,
        rect: Rect.fromCircle(center: Offset(target.x, target.y - _kHexagonMargin), radius: _kHexagonRadius),
        child: Padding(
          padding: const EdgeInsets.all(_kHexagonMargin),
          child: HexagonWidget(color: Colors.greenAccent.withOpacity(0.4)),
        ),
      ),
      Positioned.fromRect(
        // duration: const Duration(milliseconds: 100),
        // curve: Curves.easeOutQuart,
        rect: Rect.fromCircle(center: Offset(spawn.x, spawn.y - _kHexagonMargin), radius: _kHexagonRadius),
        child: Padding(
          padding: const EdgeInsets.all(_kHexagonMargin),
          child: HexagonWidget(color: Colors.redAccent.withOpacity(0.4)),
        ),
      ),
    ];
  }

  Widget towerBuildings() {

    return StreamBuilder(
      stream: gameManager.buildingsManager.onBuildingsStream(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final value = snapshot.data!;
        return Stack(
          fit: StackFit.expand,
          children: value.map((e) {
            final point = _board.boardPointToPoint(e.location);
            return Positioned.fromRect(
              key: ValueKey(e.location),
              rect: Rect.fromCircle(center: Offset(point.x, point.y - _kHexagonMargin), radius: _kHexagonRadius * 0.7),
              child: TowerWidget(model: e),
            );
          }).toList(),
        );
      }
    );

  }

  Widget rectPositionedGenerate(Rect rect, Widget child) {
    return Positioned.fromRect(
      rect: rect,
      child: child,
    );
  }

  double getAngle(double degree) {
    return degree * pi / 180.0;
  }

  Widget guideIndicator() {
    return Selector<GameManager, Map<BoardPoint, HexagonDirection>>(
        selector: (context, vm) => vm.guide,
        builder: (context, value, _) {
          return Stack(
            fit: StackFit.expand,
            children: value.entries.map((e) {
              final point = _board.boardPointToPoint(e.key);
              return Positioned.fromRect(
                rect: Rect.fromCircle(center: Offset(point.x, point.y - _kHexagonMargin), radius: _kHexagonRadius * 0.7),
                child: Center(
                  child: Transform.rotate(
                    angle: getAngle(e.value.degree),
                    child: const Icon(Icons.arrow_forward, color: Colors.blueGrey)
                  ),
                ),
              );
            }).toList(),
          );
        }
    );
  }

  Widget buildEnemies() {
    return StreamBuilder<List<Enemy>>(
      stream: gameManager.enemyManager.onEnemiesStream(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final enemies = snapshot.data!;
        return Stack(
          fit: StackFit.expand,
          children: enemies.map((e) {
            final offset = e.renderOffset!;
            return Positioned.fromRect(
              // duration: 800.ms,
              // curve: Curves.easeInOutQuart,
              key: ObjectKey(e),
              rect: Rect.fromCircle(center: Offset(offset.dx, offset.dy - _kHexagonMargin), radius: _kHexagonRadius * 0.3),
              child: const EnemyWidget(),
            );
          }).toList(),
        );
      }
    );
  }

  // Widget drawUnits() {
  //   return Selector<TimeLineSystem, List<GameUnit>>(
  //     selector: (context, manager) => manager.list,
  //     shouldRebuild: (pre, next) => pre != next,
  //     builder: (context, list, _) {
  //       return Stack(
  //         fit: StackFit.expand,
  //         children: list.map((e) => e.render(_board)).toList(),
  //       );
  //     }
  //   );
  // }

}



class CircleShader extends StatelessWidget {
  final double radius;
  final Widget child;

  const CircleShader({super.key, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return RadialGradient(
          radius: radius,
          colors: const [Colors.transparent, Colors.black],
          stops: const [0.95, 1.0],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
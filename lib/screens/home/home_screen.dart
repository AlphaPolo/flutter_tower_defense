import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:tower_defense/manager/enemy_manager.dart';
import 'package:tower_defense/manager/projectile_manager.dart';
import 'package:tower_defense/manager/wave_manager.dart';
import 'package:tower_defense/widget/game/tool/building_bottom_panel.dart';

import '../../manager/game_manager.dart';
import '../../manager/buildings_manager.dart';
import '../../providers/game_event_provider.dart';
import '../../providers/player_provider.dart';
import '../../widget/game/tool/left_col.dart';
import '../game/game_board.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Key uniqueKey = UniqueKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The scene is drawn by a CustomPaint, but user interaction is handled by
    // the InteractiveViewer parent widget.
    return Scaffold(
      key: uniqueKey,
      // backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.black87,
      body: MultiProvider(
        providers: [
          Provider(create: (context) => GameEventProvider(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => ProjectileManager(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => BuildingsManager(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => EnemyManager(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => WaveManager(), dispose: (context, manager) => manager.dispose(), lazy: false),
          Provider(create: (context) => GameManager.from(context), dispose: (context, manager) => manager.dispose(), lazy: false),
          ChangeNotifierProvider(create: (context) => PlayerProvider(context)),

        ],
        child: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              GameBoard(),
                              LeftCol(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottomCol(),
                ],
              ),
            ),
            buildGameOverOverlay(),
          ],
        ),
      ),
    );
  }

  IconButton get resetButton {
    return IconButton(
      tooltip: 'Reset',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.replay),
      onPressed: () {},
    );
  }

  IconButton get editButton {
    return IconButton(
      onPressed: () {},
      tooltip: 'Edit',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.edit),
    );
  }

  IconButton get changeStateButton {
    return IconButton(
      onPressed: () {},
      tooltip: 'MotionEdit',
      color: Theme.of(context).colorScheme.surface,
      icon: const Icon(Icons.accessibility),
    );
  }

  Widget bottomCol() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 3,
                offset: const Offset(0, -2), // changes position of shadow
              ),
            ],
          ),
          child: const BuildingBottomPanel(),
        ),
      ],
    );
  }

  Widget buildGameOverOverlay() {
    return Builder(
      builder: (context) {
        return StreamBuilder<GameState>(
          stream: context.read<GameEventProvider>().onGameStateStream(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data == GameState.gameOver) {
              return Positioned.fill(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// barrier
                    Container(color: Colors.black12).animate().fadeIn(),

                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Game Over', style: TextStyle(color: Colors.grey, fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 16.0),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  uniqueKey = UniqueKey();
                                });
                                // context.read<GameManager>().reset();
                              },
                              child: const Text('Restart'),
                            ),
                          ],
                        ),
                      ),
                    ).animate()
                        .effect(duration: 1.seconds)
                        .fadeIn()
                        .slideY(begin: -0.2, curve: Curves.easeInOutQuart),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}




import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/overlays/game_overlays.dart';
import '../../game/tower_defense_game.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TowerDefenseGame game;

  @override
  void initState() {
    super.initState();
    game = TowerDefenseGame();
  }

  /// 重新開始：建立全新的遊戲實例（GameWidget 會自動釋放舊的）。
  void _restart() {
    setState(() {
      game = TowerDefenseGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Column(
        children: [
          Expanded(
            child: GameWidget<TowerDefenseGame>(
              key: ValueKey(game),
              game: game,
              overlayBuilderMap: {
                'leftCol': (context, g) => LeftColOverlay(game: g),
                'end': (context, g) => EndOverlay(game: g, onRestart: _restart),
              },
              initialActiveOverlays: const ['leftCol', 'end'],
            ),
          ),
          BuildBar(game: game),
        ],
      ),
    );
  }
}

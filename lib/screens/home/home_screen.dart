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
      // 不透明深色底（原本 Colors.black87 是 87% 半透明 → 分頁列/邊緣會透出半透明感）。
      backgroundColor: Colors.black,
      // 設定抽屜：由左上「設定」鈕開啟；關閉邊緣滑動手勢，避免與棋盤拖曳衝突。
      drawer: SettingsDrawer(game: game),
      drawerEnableOpenDragGesture: false,
      body: Column(
        children: [
          Expanded(
            child: GameWidget<TowerDefenseGame>(
              key: ValueKey(game),
              game: game,
              overlayBuilderMap: {
                'leftCol': (context, g) =>
                    LeftColOverlay(game: g, onRestart: _restart),
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

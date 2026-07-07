import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../game/audio/game_audio.dart';
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
    GameAudio.restart(); // 停掉勝/敗 jingle、恢復 BGM
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
      // 用 Stack 讓「結束彈窗」蓋住整個畫面（含底部 BuildBar），否則遊戲勝/敗時
      // 底部的建造列仍可點擊。EndOverlay 未結束時回傳 SizedBox.shrink，不擋操作。
      // Listener：網頁的聲音需要「首次使用者互動」後才能出聲 → 第一次按下任何
      // 位置就初始化音訊引擎並開始 BGM（冪等，之後呼叫無作用）。
      body: Listener(
        onPointerDown: (_) => GameAudio.ensureStarted(),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: GameWidget<TowerDefenseGame>(
                key: ValueKey(game),
                game: game,
                overlayBuilderMap: {
                  'leftCol': (context, g) =>
                      LeftColOverlay(game: g, onRestart: _restart),
                },
                initialActiveOverlays: const ['leftCol'],
              ),
            ),
            BuildBar(game: game),
          ],
        ),
        Positioned.fill(
          child: EndOverlay(game: game, onRestart: _restart),
        ),
      ],
    );
  }
}

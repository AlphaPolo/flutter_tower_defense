import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// 是否已在開場選單選好模式（闖關/無盡）；重新開始會回到選單。
  bool _modeChosen = false;

  @override
  void initState() {
    super.initState();
    game = TowerDefenseGame();
  }

  /// 重新開始：建立全新的遊戲實例（GameWidget 會自動釋放舊的），
  /// 直接重開「目前的模式」、不回主選單。
  void _restart() {
    GameAudio.restart(); // 停掉勝/敗 jingle、恢復 BGM
    final endless = game.endless.value;
    setState(() {
      game = TowerDefenseGame();
      game.endless.value = endless; // 保留模式
    });
  }

  /// 返回主選單：全新遊戲實例 + 重新顯示模式選單（由設定抽屜觸發）。
  void _backToMenu() {
    GameAudio.restart();
    setState(() {
      game = TowerDefenseGame();
      _modeChosen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 不透明深色底（原本 Colors.black87 是 87% 半透明 → 分頁列/邊緣會透出半透明感）。
      backgroundColor: Colors.black,
      // 設定抽屜：由左上「設定」鈕開啟；關閉邊緣滑動手勢，避免與棋盤拖曳衝突。
      drawer: SettingsDrawer(game: game, onBackToMenu: _backToMenu),
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

  /// 桌面鍵盤快捷鍵：空白鍵＝開波、Esc＝取消選取、1/2/3＝遊戲倍速。
  /// 彈窗是獨立 focus scope、輸入框聚焦時另有 EditableText 守門 →
  /// 打字不會誤觸。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_modeChosen) return KeyEventResult.ignored;
    final ended = game.gameOver.value || game.gameWon.value;
    if (ended) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>() !=
        null) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      final allDone = !game.endless.value &&
          game.waveNumber >= TowerDefenseGame.totalWaves;
      if (!game.waveRunning.value && !allDone) game.startGame();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      game.cancelSelection();
      return KeyEventResult.handled;
    }
    final d = int.tryParse(event.character ?? '');
    if (d != null && d >= 1 && d <= 3) {
      if (game.gameSpeed.value != d) {
        GameAudio.ui('click', volume: 0.5);
        game.gameSpeed.value = d;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _body() {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: _stack(),
    );
  }

  Widget _stack() {
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
        // 開場模式選單：蓋住整個畫面（含底部建造列），選完才能操作。
        if (!_modeChosen)
          Positioned.fill(
            child: ModeSelectOverlay(
              game: game,
              onChosen: (endless) => setState(() {
                game.endless.value = endless;
                _modeChosen = true;
              }),
            ),
          ),
      ],
    );
  }
}

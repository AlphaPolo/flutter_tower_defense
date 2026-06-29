import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../gen/assets.gen.dart';
import '../../utils/fullscreen.dart';
import '../board/hex.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

/// 每種塔在選單 / 資訊面板上顯示的圖示。
Widget towerIcon(TowerType type) {
  switch (type) {
    case TowerType.freezing:
      return Assets.images.ice.image();
    case TowerType.flame:
      return Assets.images.fire.image();
    case TowerType.airBlade:
      return Assets.images.air.image();
    case TowerType.thunder:
      return Assets.images.electricity.image();
    case TowerType.cannon:
      return Image.asset('assets/iso/tower_cannon.png');
    case TowerType.poison:
      return Image.asset('assets/iso/tower_poison.png');
    case TowerType.obstacle:
      return const Icon(Icons.hexagon_outlined, color: Colors.brown, size: 64);
  }
}

/// HUD overlay：左下放作弊開關/狀態表/開始鈕，右下放塔資訊/建築資訊面板。
class LeftColOverlay extends StatelessWidget {
  const LeftColOverlay({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 左下角
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cheatSwitch(),
              _statusPanel(),
              _startButton(),
            ],
          ),
          const Spacer(),
          // 右下角：選取的塔資訊 / 已蓋建築資訊
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _infoPanel(),
              _inspectPanel(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cheatSwitch() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.cheat,
      builder: (context, cheat, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoSwitch(
              value: cheat,
              onChanged: (_) => game.toggleCheat(),
            ),
            const SizedBox(width: 8),
            Text(
              '作弊模式',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cheat ? Colors.greenAccent : Colors.grey[400],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('狀態表'),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: game.wave,
            builder: (context, w, _) => Row(children: [
              const Icon(Icons.waves),
              const SizedBox(width: 16.0),
              Text(w == 0 ? '準備中' : '$w/${TowerDefenseGame.totalWaves}'),
            ]),
          ),
          ValueListenableBuilder<int>(
            valueListenable: game.heart,
            builder: (context, heart, _) => Row(children: [
              const Icon(Icons.favorite),
              const SizedBox(width: 16.0),
              Text('$heart'),
            ]),
          ),
          ValueListenableBuilder<int>(
            valueListenable: game.coin,
            builder: (context, coin, _) => Row(children: [
              const Icon(Icons.attach_money),
              const SizedBox(width: 16.0),
              Text('$coin'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoPanel() {
    return ValueListenableBuilder<TowerType?>(
      valueListenable: game.selecting,
      builder: (context, type, _) {
        if (type == null) return const SizedBox.shrink();
        final stats = statsOf(type);
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 160),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox.square(
                  dimension: 48,
                  child: towerIcon(type),
                ),
              ),
              const SizedBox(height: 16.0),
              Text(stats.title, textAlign: TextAlign.center),
              const SizedBox(height: 16.0),
              Text(stats.description),
              const SizedBox(height: 16.0),
              Text('花費: ${stats.cost}'),
              Text('範圍: ${stats.range}'),
              Text('傷害: ${stats.damage}'),
            ],
          ),
        );
      },
    );
  }

  /// 點到已蓋建築時，顯示該建築資訊 + 拆除按鈕。
  Widget _inspectPanel() {
    return ValueListenableBuilder<BoardPoint?>(
      valueListenable: game.inspecting,
      builder: (context, bp, _) {
        if (bp == null) return const SizedBox.shrink();
        final type = game.typeAt(bp);
        if (type == null) return const SizedBox.shrink();
        final stats = statsOf(type);
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 160),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox.square(dimension: 48, child: towerIcon(type)),
              ),
              const SizedBox(height: 12),
              Text(stats.title, textAlign: TextAlign.center),
              if (type != TowerType.obstacle) ...[
                const SizedBox(height: 8),
                Text('範圍: ${stats.range}'),
                Text('傷害: ${stats.damage}'),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => game.demolishAt(bp),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('拆除'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _startButton() {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [game.gameOver, game.gameWon, game.waveRunning, game.wave],
      ),
      builder: (context, _) {
        final ended = game.gameOver.value || game.gameWon.value;
        final running = game.waveRunning.value;
        final allDone = game.waveNumber >= TowerDefenseGame.totalWaves;
        final canStart = !ended && !running && !allDone;

        final String label;
        if (running) {
          label = '第 ${game.waveNumber} 波進行中…';
        } else if (allDone) {
          label = '全部完成';
        } else if (game.waveNumber == 0) {
          label = '開始遊戲';
        } else {
          label = '下一波 (${game.waveNumber + 1}/${TowerDefenseGame.totalWaves})';
        }

        final button = ElevatedButton.icon(
          onPressed: canStart ? game.startGame : null,
          icon: const Icon(Icons.play_circle),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade600,
            disabledForegroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );

        return Padding(
          padding: const EdgeInsets.all(8),
          // 可按時用輕微脈動提示玩家「現在可以開下一波了」。
          child: canStart
              ? button
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1.0,
                    end: 1.06,
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                  )
              : button,
        );
      },
    );
  }
}

/// 底部：防禦塔選單。點擊選取要蓋的塔。
class BuildBar extends StatelessWidget {
  const BuildBar({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  for (final type in TowerType.values) _icon(type),
                ],
              ),
            ),
            // 右上角全螢幕鈕（僅 web）。
            if (kIsWeb)
              Positioned(
                top: 0,
                right: 0,
                child: _fullscreenButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fullscreenButton() {
    return IconButton(
      iconSize: 28,
      tooltip: '全螢幕',
      onPressed: toggleFullscreen,
      icon: const Icon(Icons.fullscreen, color: Colors.white),
    );
  }

  Widget _icon(TowerType type) {
    final button = InkWell(
      onTap: () => game.selectTower(type),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 3,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: towerIcon(type),
      ),
    );

    if (type != TowerType.obstacle) return button;

    // 障礙物顯示剩餘數量。
    return ValueListenableBuilder<int>(
      valueListenable: game.freeObstacle,
      builder: (context, count, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: button,
    );
  }
}

/// 遊戲結束：遮罩 + 勝利 / 失敗卡片 + 重新開始。
class EndOverlay extends StatelessWidget {
  const EndOverlay({super.key, required this.game, required this.onRestart});
  final TowerDefenseGame game;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.gameOver, game.gameWon]),
      builder: (context, _) {
        final won = game.gameWon.value;
        final lost = game.gameOver.value;
        if (!won && !lost) return const SizedBox.shrink();

        return Stack(
          alignment: Alignment.center,
          children: [
            const ModalBarrier(color: Colors.black12, dismissible: false),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      won ? 'You Win!' : 'Game Over',
                      style: TextStyle(
                        color: won ? Colors.green : Colors.grey,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: onRestart,
                      child: const Text('Restart'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

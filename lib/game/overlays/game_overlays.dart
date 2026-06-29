import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tower_defense/utils/bottom_semicircle_clipper.dart';

import '../../utils/fullscreen.dart';
import '../board/hex.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

/// 每種塔在選單 / 資訊面板上顯示的圖示。
/// 統一使用較正面取景渲染的外觀圖（與蓋在地圖上的 isometric 角度不同），
/// BoxFit.contain 讓裁切後的塔身維持比例並置中。
Widget towerIcon(TowerType type) {
  // 檔名一律小寫（airBlade → icon_airblade.png），避免 case-sensitive 部署找不到。
  return Image.asset(
    'assets/iso/icon_${type.name.toLowerCase()}.png',
    fit: BoxFit.contain,
  );
}

/// HUD overlay：左下放作弊開關/狀態表/開始鈕，右下放塔資訊/建築資訊面板。
class LeftColOverlay extends StatelessWidget {
  const LeftColOverlay({super.key, required this.game});
  final TowerDefenseGame game;

  @override
  Widget build(BuildContext context) {
    // SafeArea：避開瀏海/瀏覽器列；LayoutBuilder：把面板高度限制在可視範圍內，
    // 配合 SingleChildScrollView 確保橫向矮螢幕不會爆版。面板都靠角落擺放，
    // 中央棋盤維持可點擊。
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                // 左上：狀態列 + 作弊開關
                Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusPill(),
                      const SizedBox(height: 8),
                      _cheatSwitch(),
                    ],
                  ),
                ),
                // 左下：開始 / 下一波
                Align(
                  alignment: Alignment.bottomLeft,
                  child: _startButton(),
                ),
                // 右側：選取塔資訊 / 已蓋建築資訊（限高、可捲動）
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: c.maxHeight),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _infoPanel(),
                          _inspectPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 半透明深色膠囊：波數 / 生命 / 金幣，橫向排列省空間且在棋盤上清楚可讀。
  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat(Icons.waves, Colors.lightBlueAccent, game.wave,
              (w) => w == 0 ? '—' : '$w/${TowerDefenseGame.totalWaves}'),
          const SizedBox(width: 14),
          _stat(Icons.favorite, Colors.redAccent, game.heart, (v) => '$v'),
          const SizedBox(width: 14),
          _stat(Icons.monetization_on, Colors.amber, game.coin, (v) => '$v'),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, ValueListenable<int> listenable,
      String Function(int) fmt) {
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            fmt(v),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cheatSwitch() {
    return ValueListenableBuilder<bool>(
      valueListenable: game.cheat,
      builder: (context, cheat, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.7,
                child: CupertinoSwitch(
                  value: cheat,
                  onChanged: (_) => game.toggleCheat(),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '作弊',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cheat ? Colors.greenAccent : Colors.grey[300],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoPanel() {
    return ValueListenableBuilder<TowerType?>(
      valueListenable: game.selecting,
      builder: (context, type, _) {
        if (type == null) return const SizedBox.shrink();
        final stats = statsOf(type);
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 150),
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
                  child: ClipPath(
                    clipper: const BottomSemicircleClipper(),
                    child: towerIcon(type),
                  ),
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

  /// 點到格子時顯示資訊：塔(可拆除) / 主堡 / 敵人出生點。
  Widget _inspectPanel() {
    return ValueListenableBuilder<BoardPoint?>(
      valueListenable: game.inspecting,
      builder: (context, bp, _) {
        if (bp == null) return const SizedBox.shrink();

        late final Widget icon;
        late final String title;
        late final List<String> lines;
        var tower = false;

        if (bp == game.targetLocation) {
          icon = const Icon(Icons.castle, color: Colors.green, size: 44);
          title = '主堡（終點）';
          lines = ['守住這裡！', '敵人抵達會扣 1 生命', '生命歸零即遊戲結束'];
        } else if (bp == game.spawnLocation) {
          icon = const Icon(Icons.flag, color: Colors.redAccent, size: 44);
          title = '敵人出生點';
          lines = ['敵人從這裡出現', '沿著路線前往主堡'];
        } else {
          final type = game.typeAt(bp);
          if (type == null) return const SizedBox.shrink();
          tower = true;
          final stats = statsOf(type);
          icon = SizedBox.square(dimension: 48, child: ClipOval(child: towerIcon(type)));
          title = stats.title;
          lines = type == TowerType.obstacle
              ? const ['阻擋敵人前進']
              : ['範圍: ${stats.range}', '傷害: ${stats.damage}'];
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 150),
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
              Center(child: icon),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 13)),
              if (tower) ...[
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // 預留右側空間給全螢幕鈕，避免最右邊的塔被蓋住點不到。
                padding: EdgeInsets.only(right: kIsWeb ? 48 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: [
                    for (final type in TowerType.values) _icon(type),
                  ],
                ),
              ),
              // 右側全螢幕鈕（僅 web），垂直置中、不與塔重疊。
              if (kIsWeb)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _fullscreenButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullscreenButton() {
    return IconButton(
      iconSize: 26,
      tooltip: '全螢幕',
      onPressed: toggleFullscreen,
      icon: const Icon(Icons.fullscreen, color: Colors.white),
    );
  }

  Widget _icon(TowerType type) {
    final button = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 3,
          ),
        ],
      ),
      // Material(圓形 + 裁切) + InkWell(圓形邊界) → 圓形水波，不再是方形。
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => game.selectTower(type),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: Colors.brown, width: 5, strokeAlign: BorderSide.strokeAlignCenter)),
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: towerIcon(type)),
          ),
        ),
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

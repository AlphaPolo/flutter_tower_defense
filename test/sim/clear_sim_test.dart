import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

import 'sim_harness.dart';

/// 方法 A 通關模擬器：headless 跑「真正的」TowerDefenseGame（真素材、真元件、真
/// update 迴圈），程式化布防後手動驅動 25 波，看是否 gameWon。
///
/// 共用邏輯在 sim_harness.dart；勝率量測工具見 balance_rate_test.dart。
void main() {
  testWidgets('通關模擬A：純戰鬥可行性（無限金幣、迷宮+滿升）', (tester) async {
    final game = await bootSim(tester);
    game.cheat.value = true;

    final mazeLen = buildMaze(game);
    final placed = placeTowersMaxed(game);
    tickSim(game, 10);
    debugPrint('迷宮後 route=$mazeLen 格，放置 ${placed.length} 座塔');

    final report = runWavesReport(game, '\n=== A. 純戰鬥可行性 ===\n');
    debugPrint(report);
    expect(game.gameWon.value, isTrue, reason: '迷宮+滿升鋪滿都無法通關 → 過難');
  });

  testWidgets('通關模擬B：真實經濟（150金/3障礙、邊打邊蓋）', (tester) async {
    final game = await bootSim(tester);
    // cheat 預設 false → 真實金幣與障礙物限制

    final result = runEconomicGame(game);
    debugPrint('\n=== B. 真實經濟 ===\n'
        '${result.won ? "✅ 通關!" : "❌ 未通關（第 ${result.endWave} 波倒下）"} '
        'heart=${result.heart}');

    expect(game.gameWon.value, isTrue,
        reason: '真實經濟 + 合理打法都無法通關 → 過難，需調整平衡');
  });

  testWidgets('通關模擬C：真實自動演示元件 AutoPlayer 能通關', (tester) async {
    final game = await bootSim(tester);
    game.startAutoDemo(); // 用「產品」的自動演示邏輯（AutoPlayer + autoSpend）
    var frames = 0;
    while (!game.gameWon.value && !game.gameOver.value && frames < 300000) {
      game.update(1 / 60);
      frames++;
    }
    debugPrint('AutoPlayer 結果：${game.gameWon.value ? "✅ 通關" : "❌ GG"} '
        'heart=${game.heart.value} wave=${game.waveNumber}');
    expect(game.gameWon.value, isTrue, reason: '產品自動演示無法通關');
  });

  testWidgets('隨機天然環境不會封死路線', (tester) async {
    final game = TowerDefenseGame(); // withEnvironment 預設 true
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      final sw = Stopwatch()..start();
      while (!game.isLoaded && sw.elapsed < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(game.isLoaded, isTrue);
    expect(game.environment.length, inInclusiveRange(1, 10));
    // 路線仍能從出生點走到主堡（沒被環境封死）。
    expect(game.route.first, game.spawnLocation);
    expect(game.route.last, game.targetLocation);
  });
}

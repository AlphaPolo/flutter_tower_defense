import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/overlays/game_overlays.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

void _noop() {}

/// 模擬橫向矮螢幕手機，確認 HUD 與底部塔列不會爆版（RenderFlex overflow）。
void main() {
  Future<void> pumpHud(
    WidgetTester tester,
    Size size, {
    TowerType? selecting,
  }) async {
    final game = TowerDefenseGame();
    // 開始按鈕的脈動是無限動畫，測試環境會留下 pending timer，設為進行中關閉脈動。
    game.waveRunning.value = true;
    if (selecting != null) game.selecting.value = selecting;

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const ColoredBox(color: Colors.black),
                    LeftColOverlay(game: game, onRestart: _noop),
                  ],
                ),
              ),
              BuildBar(game: game),
            ],
          ),
        ),
      ),
    );
    // 讓金幣 count-up / 圖示彈跳等「有限」動畫跑完，避免殘留 timer（脈動已由
    // waveRunning=true 關閉）。
    await tester.pumpAndSettle();
  }

  testWidgets('HUD 在橫向矮螢幕不爆版（待機）', (tester) async {
    await pumpHud(tester, const Size(680, 320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD 在橫向矮螢幕不爆版（顯示塔資訊面板）', (tester) async {
    await pumpHud(tester, const Size(640, 300), selecting: TowerType.flame);
    expect(tester.takeException(), isNull);
  });

  testWidgets('點塔升級面板不爆版（Lv2 兩分支 → Lv3 兩葉）', (tester) async {
    final game = TowerDefenseGame();
    game.waveRunning.value = true;
    // 這兩個平常在 onLoad 設定；測試不跑 onLoad，手動給值讓資訊面板能判斷格子。
    game.targetLocation = const BoardPoint(0, -5);
    game.spawnLocation = const BoardPoint(0, 5);
    const bp = BoardPoint(0, 0); // 非主堡/出生點 → 視為塔
    game.towers[bp] = buildTower(TowerType.freezing, bp);
    game.inspecting.value = bp; // 打開已蓋塔的資訊/升級面板

    tester.view.physicalSize = const Size(640, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const ColoredBox(color: Colors.black),
                    LeftColOverlay(game: game, onRestart: _noop),
                  ],
                ),
              ),
              BuildBar(game: game),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // Lv1 → 兩張分支選項卡

    // 升到 Lv2 → 出現該分支底下兩張葉卡，面板重建後仍不爆版
    game.towers[bp]!.applyUpgrade(kTowerUpgradeTree[TowerType.freezing]!.first);
    game.towerChanged.value++;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

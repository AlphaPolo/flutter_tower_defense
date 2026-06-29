import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/overlays/game_overlays.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

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
                    LeftColOverlay(game: game),
                  ],
                ),
              ),
              BuildBar(game: game),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('HUD 在橫向矮螢幕不爆版（待機）', (tester) async {
    await pumpHud(tester, const Size(680, 320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD 在橫向矮螢幕不爆版（顯示塔資訊面板）', (tester) async {
    await pumpHud(tester, const Size(640, 300), selecting: TowerType.flame);
    expect(tester.takeException(), isNull);
  });
}

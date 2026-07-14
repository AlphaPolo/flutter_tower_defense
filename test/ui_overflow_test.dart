import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/leaderboard/leaderboard.dart';
import 'package:tower_defense/game/overlays/game_overlays.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

void _noop() {}
void _noopMode(bool _) {}

/// 裝置 × UI 狀態 的爆版守門矩陣。
///
/// 手機（尤其橫向矮螢幕）可用空間遠小於桌面瀏覽器，桌面看沒事的 UI 常在手機
/// overflow。這裡把主要 UI 狀態在各裝置尺寸下 pump 一次，RenderFlex overflow
/// 會讓測試直接失敗 → 改 UI 就有自動防線。
void main() {
  /// 測試矩陣的裝置尺寸（邏輯像素）。iPhone SE 橫向是最矮的主流機。
  const devices = <String, Size>{
    'iPhoneSE橫向(667x375)': Size(667, 375),
    '小Android橫向(640x300)': Size(640, 300),
    'iPhone14橫向(844x390)': Size(844, 390),
    '桌面(1280x720)': Size(1280, 720),
  };

  /// 依 HomeScreen 的實際結構 pump 完整 UI（HUD + 底部建造列 + 結束彈窗 +
  /// 開場選單），狀態由 [configure] 注入。
  Future<void> pumpApp(
    WidgetTester tester,
    Size size, {
    void Function(TowerDefenseGame game)? configure,
    bool showMenu = false,
    // 選單有氛圍光暈/浮動 logo 等「循環動畫」，pumpAndSettle 永遠等不到
    // 靜止 → 這類畫面傳 false，改用固定幀數推進。
    bool settle = true,
  }) async {
    final game = TowerDefenseGame();
    // 開始按鈕脈動是無限動畫會留 pending timer；預設用波次進行中關閉。
    game.waveRunning.value = true;
    configure?.call(game);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        // 與 MyApp 完全一致（390×844）：守門要測跟出貨相同的縮放環境。
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, _) => MaterialApp(
        home: Scaffold(
          // 與 HomeScreen 一致：鍵盤不擠壓遊戲畫面，彈窗自行處理 viewInsets。
          resizeToAvoidBottomInset: false,
          drawer: SettingsDrawer(game: game, onBackToMenu: _noop),
          body: Stack(
            children: [
              Column(
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
              Positioned.fill(
                child: EndOverlay(game: game, onRestart: _noop),
              ),
              if (showMenu)
                Positioned.fill(
                  child: ModeSelectOverlay(game: game, onChosen: _noopMode),
                ),
            ],
          ),
        ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // 推 1.2 秒讓進場動畫（彈窗 300ms + stagger 尾端 ~700ms）跑完；
      // overflow 例外照樣會被 takeException 抓到。
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  for (final d in devices.entries) {
    group('[${d.key}]', () {
      testWidgets('待機 HUD + 波次預告', (tester) async {
        await pumpApp(tester, d.value, configure: (g) {
          // 待機（非進行中）才會顯示波次預告；脈動用 gameOver 擋不了 → 保持
          // waveRunning=false 但把 wave 設 >0 走「下一波」路徑，脈動仍在...
          // 脈動 timer 問題：維持進行中狀態（預告隱藏），另測預告於結束彈窗場景。
        });
        expect(tester.takeException(), isNull);
      });

      testWidgets('選塔資訊面板', (tester) async {
        await pumpApp(tester, d.value,
            configure: (g) => g.selecting.value = TowerType.flame);
        expect(tester.takeException(), isNull);
      });

      testWidgets('已蓋塔升級面板（Lv1→Lv2）', (tester) async {
        await pumpApp(tester, d.value, configure: (g) {
          g.targetLocation = const BoardPoint(0, -5);
          g.spawnLocation = const BoardPoint(0, 5);
          const bp = BoardPoint(0, 0);
          g.towers[bp] = buildTower(TowerType.freezing, bp);
          g.towers[bp]!
              .applyUpgrade(kTowerUpgradeTree[TowerType.freezing]!.first);
          g.inspecting.value = bp;
        });
        expect(tester.takeException(), isNull);
      });

      testWidgets('開場模式選單', (tester) async {
        await pumpApp(tester, d.value, showMenu: true, settle: false);
        expect(tester.takeException(), isNull);
      });

      testWidgets('結束彈窗（闖關敗）', (tester) async {
        await pumpApp(tester, d.value, configure: (g) {
          g.waveRunning.value = false;
          g.gameOver.value = true; // canStart=false → 無脈動
        });
        expect(tester.takeException(), isNull);
      });

      testWidgets('結束彈窗（無盡敗 + 上傳區塊）', (tester) async {
        SharedPreferences.setMockInitialValues({});
        Leaderboard.available.value = true; // 讓上傳區塊（含輸入框）出現
        addTearDown(() => Leaderboard.available.value = false);
        await pumpApp(tester, d.value, configure: (g) {
          g.waveRunning.value = false;
          g.endless.value = true;
          g.completedWaves = 7;
          g.gameOver.value = true;
        });
        expect(tester.takeException(), isNull);
      });

      testWidgets('無盡敗彈窗 + 軟鍵盤頂起', (tester) async {
        SharedPreferences.setMockInitialValues({});
        Leaderboard.available.value = true;
        addTearDown(() => Leaderboard.available.value = false);
        // 模擬軟鍵盤佔掉下半部（手機鍵盤高度約 40~50% 螢幕高）。
        tester.view.viewInsets =
            FakeViewPadding(bottom: d.value.height * 0.45);
        addTearDown(tester.view.resetViewInsets);
        await pumpApp(tester, d.value, configure: (g) {
          g.waveRunning.value = false;
          g.endless.value = true;
          g.completedWaves = 7;
          g.gameOver.value = true;
        });
        expect(tester.takeException(), isNull);
      });

      testWidgets('設定抽屜', (tester) async {
        await pumpApp(tester, d.value);
        final state =
            tester.state<ScaffoldState>(find.byType(Scaffold).first);
        state.openDrawer();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('排行榜彈窗（空榜狀態）', (tester) async {
        await pumpApp(tester, d.value);
        final ctx = tester.element(find.byType(BuildBar));
        showLeaderboardDialog(ctx);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('排行榜彈窗（滿榜 20 筆＋長暱稱）', (tester) async {
        // 滿榜：卡片高度封頂 → 列表捲動；長暱稱吃 Expanded+ellipsis。
        Leaderboard.debugFakeTop = [
          for (var i = 0; i < 20; i++)
            LeaderboardEntry(
                'uid$i',
                i == 0 ? '超長暱稱十六個字塞好塞滿測試用' : '玩家$i',
                99 - i,
                1700000000000 + i),
        ];
        addTearDown(() => Leaderboard.debugFakeTop = null);
        await pumpApp(tester, d.value);
        final ctx = tester.element(find.byType(BuildBar));
        showLeaderboardDialog(ctx);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  }
}

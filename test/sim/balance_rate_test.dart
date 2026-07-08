@Tags(['balance'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sim_harness.dart';

/// 平衡量測工具：重複跑 N 場「真實經濟」模擬，統計勝率與失敗波數分布。
///
/// 一般 `flutter test` 不會跑（tag 設 skip）；手動執行：
///   flutter test --run-skipped -t balance test/sim/balance_rate_test.dart
/// 調整場數：
///   flutter test --run-skipped -t balance --dart-define=RUNS=30 test/sim/...
///
/// 用途：調平衡（敵人數值/權重/經濟）前後各量一次，用數字說話，
/// 而不是靠單次模擬的運氣。
void main() {
  const runs = int.fromEnvironment('RUNS', defaultValue: 20);

  testWidgets(
    '勝率量測：真實經濟模擬 ×$runs',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      var wins = 0;
      final failures = <({int endWave, int heart})>[];
      final sw = Stopwatch()..start();

      for (var i = 0; i < runs; i++) {
        final game = await bootSim(tester); // 每場全新 game（舊的由 pumpWidget 汰換）
        final r = runEconomicGame(game);
        if (r.won) {
          wins++;
        } else {
          failures.add((endWave: r.endWave, heart: r.heart));
          // 失敗場印逐波軌跡（漏血/塔數/組成）→ 對症下藥而不是瞎猜。
          debugPrint('─── 失敗軌跡 ───\n${r.log.join('\n')}');
        }
        debugPrint('run ${(i + 1).toString().padLeft(2)}/$runs: '
            '${r.won ? "✅" : "❌ 第 ${r.endWave} 波倒下"}');
      }

      final rate = (wins / runs * 100).toStringAsFixed(0);
      final buf = StringBuffer('\n═══ 勝率報告（${sw.elapsed.inSeconds}s）═══\n')
        ..writeln('勝率：$wins/$runs（$rate%）');
      if (failures.isNotEmpty) {
        final byWave = <int, int>{};
        for (final f in failures) {
          byWave[f.endWave] = (byWave[f.endWave] ?? 0) + 1;
        }
        buf.writeln('失敗波數分布：'
            '${(byWave.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => "第${e.key}波×${e.value}").join("、")}');
      }
      debugPrint(buf.toString());
      // 量測工具：不設門檻、永遠通過；判讀交給人。
    },
  );
}

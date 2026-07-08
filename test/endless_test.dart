import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

/// 無盡模式規則（不跑完整模擬，只驗規則面）。
void main() {
  test('Boss 波判定：闖關固定清單、無盡每 5 波', () {
    final g = TowerDefenseGame(withEnvironment: false);
    // 闖關：只有 10/15/20/25。
    expect(g.isBossWave(10), isTrue);
    expect(g.isBossWave(25), isTrue);
    expect(g.isBossWave(30), isFalse); // 闖關不會有 26+，判定上也不算
    expect(g.isBossWave(12), isFalse);
    // 無盡：第 10 波起每 5 波。
    g.endless.value = true;
    expect(g.isBossWave(10), isTrue);
    expect(g.isBossWave(26), isFalse);
    expect(g.isBossWave(30), isTrue);
    expect(g.isBossWave(45), isTrue);
    expect(g.isBossWave(5), isFalse); // 未達 10 波不出 Boss
  });

  test('25 波後血量複利+移速轉化成長、移速凍結', () {
    final g = TowerDefenseGame(withEnvironment: false);
    final w25 = g.enemyStatusForWave(25);
    final w26 = g.enemyStatusForWave(26);
    final w40 = g.enemyStatusForWave(40);
    // 26 波起除了線性 +40 還乘 1.08 複利與移速轉化。
    expect(w26.totalHp, greaterThan(w25.totalHp + 40));
    expect(w40.totalHp, greaterThan(g.enemyStatusForWave(39).totalHp * 1.05));
    // 移速 25 波後凍結：任何後續波次都等於第 25 波的值。
    expect(g.enemyStatusForWave(26).speed, equals(w25.speed));
    expect(g.enemyStatusForWave(100).speed, equals(w25.speed));
    // 轉化驗證：26 波血量 = 線性×複利×(原速/凍結速)。
    final raw26 = (100.0 + 25 * 40) * 1.08;
    expect(w26.totalHp, greaterThan(raw26)); // 多了移速轉化的份
  });
}

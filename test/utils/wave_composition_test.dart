import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

/// 波次敵人組成（權重填充）的單元測試。
/// buildWaveComposition 只用到 EnemyKind.all 與亂數，不依賴棋盤/資源載入，
/// 因此可直接對未 onLoad 的 game 實例測試。
void main() {
  final game = TowerDefenseGame();

  group('buildWaveComposition', () {
    test('前兩波只有雜兵', () {
      for (final w in [1, 2]) {
        final comp = game.buildWaveComposition(w);
        expect(comp, isNotEmpty);
        expect(comp.every((k) => k.id == 'grunt'), isTrue);
      }
    });

    test('未解鎖的種類不會出現', () {
      expect(game.buildWaveComposition(2).any((k) => k.id == 'scout'), isFalse);
      final w4 = game.buildWaveComposition(4);
      expect(w4.any((k) => k.id == 'swarm'), isFalse); // swarm 解鎖於 5
      expect(w4.any((k) => k.id == 'brute'), isFalse); // brute 解鎖於 6
    });

    test('剛解鎖的種類該波至少出現 3 隻', () {
      expect(game.buildWaveComposition(3).where((k) => k.id == 'scout').length,
          greaterThanOrEqualTo(3));
      expect(game.buildWaveComposition(5).where((k) => k.id == 'swarm').length,
          greaterThanOrEqualTo(3));
      expect(game.buildWaveComposition(6).where((k) => k.id == 'brute').length,
          greaterThanOrEqualTo(3));
    });

    test('總量 = 12 + round(wave × 0.6)', () {
      expect(game.buildWaveComposition(1).length, 13); // round(0.6)=1
      expect(game.buildWaveComposition(10).length, 18); // round(6.0)=6
      expect(game.buildWaveComposition(25).length, 27); // round(15)=15
    });
  });

  group('buildWaveSchedule', () {
    test('Boss 波含巨獸，一般波不含', () {
      for (final w in [10, 15, 20, 25]) {
        expect(game.buildWaveSchedule(w).any((t) => t.kind.id == 'juggernaut'),
            isTrue);
      }
      for (final w in [1, 7, 9, 12, 14, 24]) {
        expect(game.buildWaveSchedule(w).any((t) => t.kind.id == 'juggernaut'),
            isFalse);
      }
    });

    test('招牌小隊波會在填充之外多出小隊數量', () {
      // W7 小隊 5 隻 → 總長度 = 權重填充長度 + 5
      expect(game.buildWaveSchedule(7).length,
          game.buildWaveComposition(7).length + 5);
    });
  });
}

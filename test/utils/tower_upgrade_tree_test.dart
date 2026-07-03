import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/tower_type.dart';

/// 塔升級「分支樹（Model B）」的單元測試：
/// 樹形狀、maxLevelOf、以及 mod 覆寫的疊加（葉覆寫分支覆寫基礎）。
void main() {
  const origin = BoardPoint(0, 0);

  group('升級樹形狀', () {
    test('每塔 2 分支 × 各 2 葉、且 maxLevel = 3', () {
      for (final entry in kTowerUpgradeTree.entries) {
        expect(entry.value.length, 2, reason: '${entry.key} 應有兩個 Lv2 分支');
        for (final branch in entry.value) {
          expect(branch.children.length, 2,
              reason: '${entry.key}/${branch.key} 應有兩個 Lv3 葉');
        }
        expect(maxLevelOf(entry.key), 3);
      }
    });

    test('沒有升級樹的塔 maxLevel = 1', () {
      expect(maxLevelOf(TowerType.spike), 1);
      expect(maxLevelOf(TowerType.obstacle), 1);
    });
  });

  group('mod 疊加與 level', () {
    test('火炮：分支→葉，葉覆寫分支（centerPeak 1.0 → 1.5）', () {
      final cannon =
          buildTower(TowerType.cannon, origin) as CannonTowerComponent;
      expect(cannon.level, 1);
      expect(cannon.blastHex, 1.2);
      expect(cannon.centerPeak, 0);

      final highExplosive = kTowerUpgradeTree[TowerType.cannon]![1]; // 高爆
      cannon.applyUpgrade(highExplosive);
      expect(cannon.level, 2);
      expect(cannon.centerPeak, 1.0);

      final pierce = highExplosive.children[0]; // 穿甲
      cannon.applyUpgrade(pierce);
      expect(cannon.level, 3);
      expect(cannon.centerPeak, 1.5); // 葉覆寫分支
      expect(cannon.blastHex, 1.2); // 這條沒動到 blast → 維持基礎
    });

    test('冰凍：混合葉可同時覆寫兩個 stat（range + slow）', () {
      final f =
          buildTower(TowerType.freezing, origin) as FreezingTowerComponent;
      final frostArea = kTowerUpgradeTree[TowerType.freezing]![1]; // 霜域 range 3.5
      f.applyUpgrade(frostArea);
      expect(f.range, 3.5);
      expect(f.slowFactor, 0.6); // 尚未動到 slow → 基礎

      final frostPrison = frostArea.children[1]; // 霜牢 range 3.9 + slow 0.4
      f.applyUpgrade(frostPrison);
      expect(f.range, 3.9);
      expect(f.slowFactor, 0.4);
    });
  });
}

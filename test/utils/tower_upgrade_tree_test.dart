import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/tower_type.dart';

/// 塔升級「分支樹（Model B）」的單元測試：
/// 樹形狀、maxLevelOf、以及 mod 覆寫的疊加（葉覆寫分支覆寫基礎）。
void main() {
  const origin = BoardPoint(0, 0);

  group('升級樹形狀', () {
    test('每塔 1~2 分支、每分支 2 葉、且 maxLevel = 3', () {
      for (final entry in kTowerUpgradeTree.entries) {
        expect(entry.value.length, inInclusiveRange(1, 2),
            reason: '${entry.key} 應有 1~2 個 Lv2 分支');
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

    test('火炮 齊射：混合葉可同時覆寫兩個 stat（blast + center）', () {
      final c = buildTower(TowerType.cannon, origin) as CannonTowerComponent;
      final bigBore = kTowerUpgradeTree[TowerType.cannon]![0]; // 大口徑 blast 1.9
      c.applyUpgrade(bigBore);
      expect(c.blastHex, 1.9);
      expect(c.centerPeak, 0); // 尚未動到 center → 基礎

      final salvo = bigBore.children[1]; // 齊射 blast 2.2 + center 0.6
      c.applyUpgrade(salvo);
      expect(c.blastHex, 2.2);
      expect(c.centerPeak, 0.6);
    });
  });
}

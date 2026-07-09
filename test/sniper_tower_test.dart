import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/enemy_component.dart';
import 'package:tower_defense/game/components/enemy_kind.dart';
import 'package:tower_defense/game/components/environment.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

import 'sim/sim_harness.dart';

/// 狙擊塔回歸：LoS 遮擋規則、鎖定優先序、獵首/重型/貫穿傷害、主動技獨立 CD。
void main() {
  EnemyComponent enemyAt(TowerDefenseGame game, BoardPoint p,
      {EnemyKind kind = EnemyKind.grunt, double hp = 200}) {
    final e = EnemyComponent(
      kind: kind,
      currentLocation: p,
      status: EnemyStatus(totalHp: hp, currentHp: hp, speed: 0),
    );
    game.spawnEnemy(e);
    return e;
  }

  SniperTowerComponent placeSniper(TowerDefenseGame game, BoardPoint p,
      {List<int> build = const []}) {
    final t = buildTower(TowerType.sniper, p) as SniperTowerComponent;
    game.towers[p] = t;
    game.world.add(t);
    final tree = kTowerUpgradeTree[TowerType.sniper]!;
    if (build.isNotEmpty) t.applyUpgrade(tree[build[0]]);
    if (build.length > 1) t.applyUpgrade(tree[build[0]].children[build[1]]);
    return t;
  }

  /// 跑 [frames] 幀正常速率模擬（60fps）。
  void run(TowerDefenseGame game, int frames) {
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
    }
  }

  testWidgets('LoS：高聳地形遮擋，水面與玩家建築不遮擋', (tester) async {
    final game = await bootSim(tester);
    final a = game.boardToLogical(const BoardPoint(0, 0));
    final b = game.boardToLogical(const BoardPoint(0, 2));
    expect(game.terrainBlocksLine(a, b), isFalse);

    game.environment[const BoardPoint(0, 1)] = EnvType.boulder;
    expect(game.terrainBlocksLine(a, b), isTrue);

    // 密林同為高聳 → 遮擋。
    game.environment[const BoardPoint(0, 1)] = EnvType.woods;
    expect(game.terrainBlocksLine(a, b), isTrue);

    // 水池擋路（blocks）但平坦（blocksSight=false）→ 箭飛過、不遮擋。
    game.environment[const BoardPoint(0, 1)] = EnvType.pond;
    expect(game.terrainBlocksLine(a, b), isFalse);
    game.environment.remove(const BoardPoint(0, 1));

    // 玩家建築（障礙塔）不算天然地形 → 不遮擋狙擊射線。
    game.towers[const BoardPoint(0, 1)] =
        buildTower(TowerType.obstacle, const BoardPoint(0, 1));
    expect(game.terrainBlocksLine(a, b), isFalse);
  });

  testWidgets('鎖定血量最高；被地形擋住退而求其次；彈道破除無視地形', (tester) async {
    final game = await bootSim(tester);
    game.environment[const BoardPoint(0, 1)] = EnvType.boulder;
    final blockedHigh = enemyAt(game, const BoardPoint(0, 2), hp: 300);
    final visibleLow = enemyAt(game, const BoardPoint(2, 0), hp: 100);

    final plain = placeSniper(game, const BoardPoint(0, 0));
    tickSim(game, 3); // mount
    game.update(1 / 60); // 選目標
    // 血最高的被巨石擋住 → 退而求其次鎖看得到的。
    expect(plain.target, same(visibleLow));

    // 彈道破除（losFree）：直接鎖血最高、無視巨石。
    final free = placeSniper(game, const BoardPoint(-1, 0), build: [1]);
    tickSim(game, 3);
    game.update(1 / 60);
    expect(free.target, same(blockedHigh));
  });

  testWidgets('獵首 ×1.5、神射手對重型 +40%、主動技 ×2 且與裝填 CD 獨立', (tester) async {
    final game = await bootSim(tester);
    final brute =
        enemyAt(game, const BoardPoint(0, 2), kind: EnemyKind.brute, hp: 2000);
    // A 重型槍管(dmg130, 閾值0.6) → X 神射手(heavy+40%, 技×2)。
    final sniper = placeSniper(game, const BoardPoint(0, 0), build: [0, 0]);
    tickSim(game, 3);

    // 普攻：瞄準 0.8 秒開火 + 弩箭飛行時間後命中。
    // 130 × 獵首1.5（滿血 ≥ 0.6）× 重型1.4 = 273。
    run(game, 70);
    expect(brute.status.currentHp, closeTo(2000 - 273, 0.001));
    expect(sniper.prepareShoot, greaterThan(0)); // 普攻進裝填

    // 主動技：裝填中仍可放，傷害再 ×2（血量比例 0.86 ≥ 0.6 → 獵首仍生效）。
    // 施放先射出弩箭（CD 立即消耗），傷害在飛抵時才結算。
    expect(sniper.skillReady, isTrue);
    expect(sniper.castSkillAt(brute.logicalPos.clone()), isTrue);
    expect(brute.status.currentHp, closeTo(2000 - 273, 0.001)); // 箭還在飛
    expect(sniper.skillReady, isFalse); // 技能自己進 10 秒 CD
    run(game, 20);
    expect(brute.status.currentHp, closeTo(2000 - 273 - 546, 0.001));
    expect(sniper.castSkillAt(brute.logicalPos.clone()), isFalse);
  });

  testWidgets('瞄準模式：startSkillAim 進入、castSkillToward 以螢幕座標開火並退出', (tester) async {
    final game = await bootSim(tester);
    final grunt = enemyAt(game, const BoardPoint(0, 2), hp: 400);
    const cell = BoardPoint(0, 0);
    final sniper = placeSniper(game, cell, build: [0, 0]); // 神射手（技×2）
    tickSim(game, 3);

    game.startSkillAim(cell);
    expect(game.aimingSkill.value, cell);

    // 點擊敵人所在的螢幕座標 → 朝該方向射出弩箭、退出瞄準模式。
    // 130 × 獵首1.5（滿血）× 技×2 = 390，箭飛抵才扣血。
    final ok = game.castSkillToward(game.logicalToScreen(grunt.logicalPos));
    expect(ok, isTrue);
    expect(game.aimingSkill.value, isNull);
    expect(grunt.status.currentHp, 400); // 投射物尚未命中
    run(game, 20);
    expect(grunt.status.currentHp, closeTo(400 - 390, 0.001));

    // CD 中不能再進入瞄準模式。
    game.startSkillAim(cell);
    expect(game.aimingSkill.value, isNull);
    expect(sniper.skillReady, isFalse);

    // cancelSelection 也會清掉瞄準狀態。
    sniper.skillCdLeft = 0;
    game.startSkillAim(cell);
    expect(game.aimingSkill.value, cell);
    game.cancelSelection();
    expect(game.aimingSkill.value, isNull);
  });

  testWidgets('百步穿楊：飛越遠傷害越高（每格 +10%，依各敵人的命中距離）', (tester) async {
    final game = await bootSim(tester);
    final near = enemyAt(game, const BoardPoint(0, 1), hp: 1000);
    final far = enemyAt(game, const BoardPoint(0, 4), hp: 1000);
    // C 百步穿楊 → Y 貫穿：一箭穿過兩隻，各依自己的飛行距離加成。
    placeSniper(game, const BoardPoint(0, 0), build: [2, 1]);
    tickSim(game, 3);

    run(game, 80);
    // 相鄰格心距 = 1 格。90 × 獵首1.5 × (1 + 0.10×格數)：1 格 148.5、4 格 189。
    expect(near.status.currentHp, closeTo(1000 - 148.5, 0.01));
    expect(far.status.currentHp, closeTo(1000 - 189, 0.01));
  });

  testWidgets('貫穿：一發打穿彈道上全部敵人', (tester) async {
    final game = await bootSim(tester);
    final line = [
      enemyAt(game, const BoardPoint(0, 1), hp: 400),
      enemyAt(game, const BoardPoint(0, 2), hp: 400),
      enemyAt(game, const BoardPoint(0, 3), hp: 400),
    ];
    // B 彈道破除 → Y 貫穿（技×1）。三隻與塔共線 → 弩箭沿途全部貫穿。
    placeSniper(game, const BoardPoint(0, 0), build: [1, 1]);
    tickSim(game, 3);

    run(game, 80);
    // 90 × 獵首1.5（全滿血 ≥ 0.8）= 135，三隻同時扣血。
    for (final e in line) {
      expect(e.status.currentHp, closeTo(400 - 135, 0.001));
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/projectile/projectile.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/components/trap/trap_component.dart';
import 'package:tower_defense/game/tower_type.dart';

import 'sim/sim_harness.dart';

/// 標靶樁行為：指定/拒絕/波次中持續開火/拆除自動解除。
void main() {
  testWidgets('標靶樁：指定、開火、拆除解除', (tester) async {
    final game = await bootSim(tester);
    const towerCell = BoardPoint(1, 0);
    const beaconCell = BoardPoint(-1, 1);
    const otherCell = BoardPoint(2, 0);

    // 直接注入（同模擬手法，繞過購買流程）。
    final cannon = buildTower(TowerType.cannon, towerCell);
    game.towers[towerCell] = cannon;
    game.world.add(cannon);
    final beacon = buildTrap(TowerType.beacon, beaconCell);
    game.traps[beaconCell] = beacon;
    game.world.add(beacon);
    final airBlade = buildTower(TowerType.airBlade, otherCell);
    game.towers[otherCell] = airBlade;
    game.world.add(airBlade);
    tickSim(game, 5);

    // 指定：支援的塔＋標靶格 → 成功；不支援的塔 / 非標靶格 → 拒絕。
    expect(game.setBeaconTarget(towerCell, beaconCell), isTrue);
    expect(cannon.beaconTarget, beaconCell);
    expect(game.setBeaconTarget(otherCell, beaconCell), isFalse,
        reason: '風刃塔不支援標靶');
    expect(game.setBeaconTarget(towerCell, const BoardPoint(3, 0)), isFalse,
        reason: '非標靶格不可指定');

    // 波間不開火。
    game.update(0);
    var shells =
        game.world.children.whereType<CannonProjectileComponent>().length;
    expect(shells, 0, reason: '波間應停火');

    // 波次進行中：即使沒有敵人也立即朝標靶開火（砲彈飛行 0.42s 內取樣）。
    game.waveRunning.value = true;
    for (var i = 0; i < 5; i++) {
      game.update(1 / 60);
    }
    shells = game.world.children.whereType<CannonProjectileComponent>().length;
    expect(shells, greaterThan(0), reason: '波次中應持續朝標靶開火');
    game.waveRunning.value = false;
    for (var i = 0; i < 120; i++) {
      game.update(1 / 60); // 清掉飛行中砲彈/爆炸
    }

    // 拆除標靶 → 指定自動解除。
    expect(game.demolishAt(beaconCell), isTrue);
    expect(cannon.beaconTarget, isNull, reason: '標靶被拆應自動解除');
  });
}

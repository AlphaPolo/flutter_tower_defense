import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/constant/game_constant.dart';
import 'package:tower_defense/game/components/enemy_component.dart';
import 'package:tower_defense/game/components/enemy_kind.dart';
import 'package:tower_defense/game/components/enemy_status.dart';
import 'package:tower_defense/game/effects/effect.dart';

import 'sim/sim_harness.dart';

/// 熾流抗治療：燃燒中所受治療打 kBurnHealPenalty 折。
void main() {
  testWidgets('燃燒中所受治療減半（熾流剋薩滿）', (tester) async {
    final game = await bootSim(tester);
    EnemyComponent make() => EnemyComponent(
          kind: EnemyKind.grunt,
          currentLocation: game.spawnLocation,
          status: const EnemyStatus(totalHp: 100, currentHp: 40, speed: 0),
        );
    final normal = make();
    final burning = make();
    game.spawnEnemy(normal);
    game.spawnEnemy(burning);
    tickSim(game, 3); // 處理 mount（dt=0 → 不移動、效果不結算）

    burning.addEffect(PoisonEffect(kBurnEffectType, 3000, 12));
    expect(burning.isBurning, isTrue);
    expect(normal.isBurning, isFalse);

    // 各接受 10% 最大血量的治療：一般 +10、燃燒中 +5（減半）。
    expect(normal.receiveHeal(0.10), isTrue);
    expect(burning.receiveHeal(0.10), isTrue);
    expect(normal.status.currentHp, closeTo(50, 0.001));
    expect(burning.status.currentHp, closeTo(45, 0.001));

    // 滿血不吃治療。
    normal.status = normal.status.copyWith(currentHp: 100);
    expect(normal.receiveHeal(0.10), isFalse);
  });
}

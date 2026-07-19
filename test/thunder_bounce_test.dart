import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/enemy_component.dart';
import 'package:tower_defense/game/components/enemy_kind.dart';
import 'package:tower_defense/game/components/projectile/projectile.dart';

import 'sim/sim_harness.dart';

/// 雷電彈跳：命中「當下」才找下一個目標彈射 → 三個目標的首次受擊
/// 幀數必須嚴格遞增（不再是整條鏈同幀結算）。
void main() {
  testWidgets('雷電連鎖：逐跳結算、時序遞增', (tester) async {
    final game = await bootSim(tester);

    // 三隻不動的敵人排成一串（相鄰格 → 都在每跳連鎖距離內）。
    const cells = [BoardPoint(0, 1), BoardPoint(-1, 2), BoardPoint(-2, 3)];
    final foes = <EnemyComponent>[];
    for (final c in cells) {
      final e = EnemyComponent(
        kind: EnemyKind.grunt,
        currentLocation: c,
        status: EnemyStatus(totalHp: 1000, currentHp: 1000, speed: 0),
      );
      foes.add(e);
      game.spawnEnemy(e);
    }
    tickSim(game, 5);

    // 直接生成投射物（基礎塔 chainLimit=1，連鎖來自升級 → 測試給 3 跳；
    // 參數比照 ThunderTowerComponent.createProjectile）。
    game.world.add(ThunderProjectileComponent(
      damage: 10,
      start: game.boardToLogical(const BoardPoint(1, 0)),
      speed: 1,
      target: foes[0],
      chainLimit: 3,
      chainDistance: 5,
    ));
    game.waveRunning.value = true;
    final firstHitFrame = List<int?>.filled(foes.length, null);
    for (var f = 0; f < 600; f++) {
      game.update(1 / 60);
      for (var i = 0; i < foes.length; i++) {
        if (firstHitFrame[i] == null &&
            foes[i].status.currentHp < foes[i].status.totalHp) {
          firstHitFrame[i] = f;
        }
      }
      if (!firstHitFrame.contains(null)) break;
    }

    expect(firstHitFrame, everyElement(isNotNull),
        reason: '三個目標都應被連鎖命中');
    expect(firstHitFrame[0]! < firstHitFrame[1]!, isTrue,
        reason: '第二跳應晚於第一跳（彈跳、非同幀結算）');
    expect(firstHitFrame[1]! < firstHitFrame[2]!, isTrue,
        reason: '第三跳應晚於第二跳');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/constant/game_constant.dart';
import 'package:tower_defense/game/effects/effect.dart';

void main() {
  test('時效性Buff測試', () {
    final timerEffect = SlowMovementEffect.flat(kThunderEffectType, 1000, 0.2);

    expect(timerEffect.dead, isFalse);

    /// 模擬每幀刷新
    for (int clock = 0; clock <= 1016; clock += 16) {
      timerEffect.tick(16);
    }

    expect(timerEffect.dead, isTrue);
  });

  test('未到時間不應失效', () {
    final timerEffect = SlowMovementEffect.flat(kThunderEffectType, 1000, 0.2);

    for (int clock = 0; clock <= 500; clock += 16) {
      timerEffect.tick(16);
    }

    expect(timerEffect.dead, isFalse);
  });
}

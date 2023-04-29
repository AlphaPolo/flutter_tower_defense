import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/constant/game_constant.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/effects/base_effect.dart';
import 'package:tower_defense/model/effects/slow_movement_effect.dart';
import 'package:tower_defense/model/enemy/enemy.dart';
import 'package:tower_defense/widget/game/board/board_painter.dart';

void main() {
  test('時效性Buff測試', () {
    final fakeTarget = Enemy(const BoardPoint(0, 0), const EnemyStatus(totalHp: 100, currentHp: 100, speed: 1.5));
    final timerEffect = SlowMovementEffect.flat(kThunderEffectType, 1000, fakeTarget, 0.2);
    final manager = GameManager();

    expect(timerEffect.dead, isFalse);

    /// 模擬每幀刷新
    for (int clock = 0; clock <= 1016; clock+=16) {
      timerEffect.tick(manager, 16);
    }

    expect(timerEffect.dead, isTrue);
  });

  test('更新Buff測試', () {
    final fakeTarget = Enemy(const BoardPoint(0, 0), const EnemyStatus(totalHp: 100, currentHp: 100, speed: 1.5));
    final timerEffect = SlowMovementEffect.flat(kThunderEffectType, 1000, fakeTarget, 0.2);
    final manager = GameManager();

    expect(timerEffect.dead, isFalse);

    /// 模擬每幀刷新
    for (int clock = 0; clock <= 500; clock+=16) {
      timerEffect.tick(manager, 16);
    }

    expect(timerEffect.dead, isFalse);

    final timerEffectUpdate = SlowMovementEffect.flat(kThunderEffectType, 1000, fakeTarget, 0.2);
    timerEffect.updateEffect(manager, timerEffectUpdate);

    expect(timerEffect.dead, isTrue);
  }, skip: true);
}
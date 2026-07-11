import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/enemy_component.dart';
import 'package:tower_defense/game/components/enemy_kind.dart';

/// 物理抗性（護甲兵）：物理傷害 ×(1-physicalResist)，元素傷害不受影響。
void main() {
  EnemyComponent spawn(EnemyKind kind) => EnemyComponent(
        kind: kind,
        currentLocation: const BoardPoint(0, 0),
        status: EnemyStatus(totalHp: 1000, currentHp: 1000, speed: 1),
      );

  test('鐵甲龜：物理傷害減半、元素傷害全額', () {
    final e = spawn(EnemyKind.turtle);
    e.dealDamage(100); // 物理（預設）→ 只吃 50
    expect(e.status.currentHp, closeTo(950, 0.001));
    e.dealDamage(100, physical: false); // 元素 → 全額
    expect(e.status.currentHp, closeTo(850, 0.001));
  });

  test('一般敵人：物理傷害不減免', () {
    final e = spawn(EnemyKind.grunt);
    e.dealDamage(100);
    expect(e.status.currentHp, closeTo(900, 0.001));
  });
}

import 'package:flame/components.dart';

import '../tower_defense_game.dart';
import 'enemy_component.dart';
import 'enemy_kind.dart';
import 'enemy_status.dart';

/// 一波敵人：依 [kinds] 的順序，每 [interval] 秒生一隻。
/// 每隻的數值 = 該波基準 [base] × 種類倍率。
/// 生完不會自己移除，由 game 偵測「生完且場上清空」後才算過關並移除。
class WaveSpawnerComponent extends Component
    with HasGameReference<TowerDefenseGame> {
  WaveSpawnerComponent({required this.kinds, required this.base});

  final List<EnemyKind> kinds;
  final EnemyStatus base;

  static const double interval = 1.0; // 1000ms

  int spawned = 0;
  double timer = 0;

  bool get isDone => spawned >= kinds.length;

  @override
  void update(double dt) {
    if (isDone) return;
    timer += dt;
    if (timer >= interval) {
      timer -= interval;
      _spawn(kinds[spawned]);
      spawned++;
    }
  }

  void _spawn(EnemyKind kind) {
    final hp = base.totalHp * kind.hpMul;
    game.world.add(
      EnemyComponent(
        kind: kind,
        currentLocation: game.spawnLocation,
        status: EnemyStatus(
          totalHp: hp,
          currentHp: hp,
          speed: base.speed * kind.speedMul,
        ),
      ),
    );
  }
}

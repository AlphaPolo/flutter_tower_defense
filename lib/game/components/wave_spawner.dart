import 'package:flame/components.dart';

import '../tower_defense_game.dart';
import 'enemy_component.dart';
import 'enemy_kind.dart';
import 'enemy_status.dart';

/// 一次生成指令：等待 [gap] 秒後生出 [kind]。
/// 小隊(combo)用很小的 gap 讓成員擠在一起出現。
class SpawnTick {
  const SpawnTick(this.kind, this.gap);
  final EnemyKind kind;
  final double gap;
}

/// 一波敵人：依 [schedule]（一串帶間隔的生成指令）逐一生成。
/// 每隻的數值 = 該波基準 [base] × 種類倍率。
/// 生完不會自己移除，由 game 偵測「生完且場上清空」後才算過關並移除。
class WaveSpawnerComponent extends Component
    with HasGameReference<TowerDefenseGame> {
  WaveSpawnerComponent({required this.schedule, required this.base});

  final List<SpawnTick> schedule;
  final EnemyStatus base;

  int spawned = 0;
  double timer = 0;

  bool get isDone => spawned >= schedule.length;

  @override
  void update(double dt) {
    if (isDone) return;
    timer += dt;
    // while：一幀可能跨過多個緊湊的小隊間隔。
    while (!isDone && timer >= schedule[spawned].gap) {
      timer -= schedule[spawned].gap;
      _spawn(schedule[spawned].kind);
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

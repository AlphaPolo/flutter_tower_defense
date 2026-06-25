import 'package:flame/components.dart';

import '../tower_defense_game.dart';
import 'enemy_component.dart';

/// 一波敵人。每 [interval] 秒生一隻，共 [total] 隻。
/// 生完不會自己移除，由 game 偵測「生完且場上清空」後才算過關並移除。
class WaveSpawnerComponent extends Component
    with HasGameReference<TowerDefenseGame> {
  WaveSpawnerComponent({required this.status, this.total = 15});

  final EnemyStatus status;
  final int total;

  static const double interval = 1.0; // 1000ms

  int spawned = 0;
  double timer = 0;

  bool get isDone => spawned >= total;

  @override
  void update(double dt) {
    if (isDone) return;
    timer += dt;
    if (timer >= interval) {
      timer -= interval;
      _spawn();
      spawned++;
    }
  }

  void _spawn() {
    game.world.add(
      EnemyComponent(
        currentLocation: game.spawnLocation,
        status: status,
      ),
    );
  }
}

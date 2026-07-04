import 'package:flame/components.dart';

import '../tower_defense_game.dart';
import 'auto_build.dart';

/// 自動演示：掛在遊戲上，波與波之間自動布防(見 [autoSpend])，再自動開下一波，
/// 全程可視。波進行中不介入（讓玩家看它打）。遊戲結束/勝利即停手。
class AutoPlayerComponent extends Component
    with HasGameReference<TowerDefenseGame> {
  @override
  void update(double dt) {
    final g = game;
    if (g.gameOver.value || g.gameWon.value) return;
    // 只有在「沒有波在跑且場上沒敵人」的空檔才建設 + 開下一波。
    if (!g.waveRunning.value && g.enemies.isEmpty) {
      autoSpend(g);
      g.startGame();
    }
  }
}

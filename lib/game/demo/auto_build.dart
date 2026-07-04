import '../board/hex.dart';
import '../components/tower/tower_component.dart';
import '../components/tower/tower_factory.dart';
import '../tower_defense_game.dart';
import '../tower_type.dart';

/// 自動演示/模擬共用的「布防策略」——經模擬驗證可通關的打法。
///
/// 核心：把塔蓋在「貼目前路線、且最能拉長路線」的格子 → 一座塔同時當迷宮牆
/// (拉長曝光時間) 又能輸出；免費障礙物拿來免錢擴牆；有餘錢再照預定 build 升級。

/// 各塔的預定升級路線 [分支 index, 葉 index]。
const autoBuilds = <TowerType, List<int>>{
  TowerType.cannon: [0, 0], // 大口徑→飽和轟炸（大 AoE）
  TowerType.airBlade: [0, 1], // 疾風→亂舞（雙刃，DPS 翻倍）
  TowerType.flame: [0, 0], // 烈焰→熔核（高 DPS）
  TowerType.poison: [1, 0], // 蝕血→深蝕（%最大血量，打坦/王）
  TowerType.freezing: [0, 0], // 深寒→絕對零度（強減速）
  TowerType.thunder: [0, 0], // 電鏈→閃電風暴（連鎖）
};

const _priority = [
  TowerType.cannon,
  TowerType.airBlade,
  TowerType.flame,
  TowerType.poison,
  TowerType.freezing,
  TowerType.thunder,
];

/// 執行一次「波間建設」：①免費障礙擴牆 ②買塔(貼路線最拉長) ③升級。
void autoSpend(TowerDefenseGame game) {
  // ① 免費障礙物：每個放最能拉長路線的貼路線格。
  while (game.freeObstacle.value > 0) {
    final cell = bestMazeCell(game);
    if (cell == null) break;
    game.towers[cell] = buildTower(TowerType.obstacle, cell);
    game.recomputeGuide();
    game.freeObstacle.value -= 1;
  }

  // ②③ 能蓋塔就蓋，否則升級，直到沒錢可用。
  var acted = true;
  while (acted) {
    acted = false;
    final built =
        game.towers.values.where((t) => t.type != TowerType.obstacle).length;
    final want = _priority[built % _priority.length];
    TowerType? type;
    if (game.coin.value >= statsOf(want).cost) {
      type = want;
    } else {
      for (final t in _priority) {
        if (game.coin.value >= statsOf(t).cost) {
          type = t;
          break;
        }
      }
    }
    if (type != null) {
      final cell = bestMazeCell(game);
      if (cell != null) {
        final tw = buildTower(type, cell);
        game.towers[cell] = tw;
        game.world.add(tw);
        game.recomputeGuide();
        game.coin.value -= statsOf(type).cost;
        acted = true;
        continue;
      }
    }
    if (_upgradeCheapest(game)) acted = true;
  }
}

/// 貼目前路線、且（試放後）最能拉長路線的可放置空格；無則回 null。
BoardPoint? bestMazeCell(TowerDefenseGame game) {
  final cands = <BoardPoint>{};
  for (final c in game.route) {
    for (final d in HexagonDirection.values) {
      final n = c.getNeighbor(d);
      if (game.isPlaceable(n)) cands.add(n);
    }
  }
  if (cands.isEmpty) return null;
  BoardPoint? best;
  var bestLen = -1;
  for (final p in cands) {
    game.towers[p] = buildTower(TowerType.obstacle, p);
    game.recomputeGuide();
    final len = game.route.length;
    game.towers.remove(p);
    game.recomputeGuide();
    if (len > bestLen) {
      bestLen = len;
      best = p;
    }
  }
  return best;
}

bool _upgradeCheapest(TowerDefenseGame game) {
  BoardPoint? bestCell;
  TowerUpgradeNode? bestNode;
  for (final entry in game.towers.entries) {
    final node = nextNode(entry.value);
    if (node == null || game.coin.value < node.cost) continue;
    if (bestNode == null || node.cost < bestNode.cost) {
      bestNode = node;
      bestCell = entry.key;
    }
  }
  if (bestCell == null) return false;
  return game.upgradeTower(bestCell, bestNode!);
}

/// 某塔朝其預定 build 的下一個升級節點；已滿級/不可升則 null。
TowerUpgradeNode? nextNode(TowerComponent t) {
  final tree = kTowerUpgradeTree[t.type];
  final path = autoBuilds[t.type];
  if (tree == null || path == null) return null;
  if (t.chosen.isEmpty) return tree[path[0]];
  if (t.chosen.length == 1) return t.chosen.first.children[path[1]];
  return null;
}

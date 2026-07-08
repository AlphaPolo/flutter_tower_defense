import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_component.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

/// 通關模擬共用 harness：headless 跑「真正的」TowerDefenseGame。
/// 由 clear_sim_test（通關門檻）與 balance_rate_test（勝率量測工具）共用。

Future<TowerDefenseGame> bootSim(WidgetTester tester) async {
  final game = TowerDefenseGame(withEnvironment: false); // 模擬不產生隨機環境
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    final sw = Stopwatch()..start();
    while (!game.isLoaded && sw.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
  tickSim(game, 10);
  expect(game.isLoaded, isTrue, reason: 'game 未在時限內載入');
  return game;
}

void tickSim(TowerDefenseGame game, int n) {
  for (var i = 0; i < n; i++) {
    game.update(0);
  }
}

String runWavesReport(TowerDefenseGame game, String title) {
  final report = StringBuffer(title);
  for (var w = 1; w <= TowerDefenseGame.totalWaves; w++) {
    final heartBefore = game.heart.value;
    game.startGame();
    var frames = 0;
    while (
        game.waveRunning.value && !game.gameOver.value && frames < 60 * 240) {
      game.update(1 / 60);
      frames++;
    }
    report.writeln('Wave ${game.waveNumber.toString().padLeft(2)}: '
        '${game.gameOver.value ? "GAME OVER" : (game.waveRunning.value ? "TIMEOUT" : "cleared")}  '
        'heart=${game.heart.value} 漏${heartBefore - game.heart.value}');
    if (game.gameOver.value || game.waveRunning.value) break;
  }
  report.writeln(game.gameWon.value ? '✅ 通關!' : '❌ 未通關');
  return report.toString();
}

/// 跑一場「真實經濟」模擬（150 金起手、波間有機建設）直到通關或失敗。
/// 回傳勝負、失敗波數、剩餘生命與逐波軌跡（漏血/塔數/組成摘要，除錯壞骰用）。
({bool won, int endWave, int heart, List<String> log}) runEconomicGame(
    TowerDefenseGame game) {
  final log = <String>[];
  for (var w = 1; w <= TowerDefenseGame.totalWaves; w++) {
    spendOrganic(game);
    tickSim(game, 5);
    final heartBefore = game.heart.value;
    final towers =
        game.towers.values.where((t) => t.type != TowerType.obstacle).length;
    game.startGame();
    var frames = 0;
    while (
        game.waveRunning.value && !game.gameOver.value && frames < 60 * 240) {
      game.update(1 / 60);
      frames++;
    }
    // 組成摘要（該波實際生成的種類×數量）。
    final counts = <String, int>{};
    for (final k in game.waveLineup(w)) {
      counts[k.name] = (counts[k.name] ?? 0) + 1;
    }
    log.add('W$w: 漏${heartBefore - game.heart.value} 塔$towers '
        '金${game.coin.value} 路${game.route.length} '
        '[${counts.entries.map((e) => "${e.key}x${e.value}").join(" ")}]');
    if (game.gameOver.value || game.waveRunning.value) break;
  }
  return (
    won: game.gameWon.value,
    endWave: game.waveNumber,
    heart: game.heart.value,
    log: log,
  );
}

/// 梳齒迷宮：每隔一列填成牆，isPlaceable 會自動留缺口；相鄰牆左右輪替 → 蛇行長路。
int buildMaze(TowerDefenseGame game) {
  const wallRows = [4, 2, 0, -2, -4];
  const r = TowerDefenseGame.boardRadius;
  for (var idx = 0; idx < wallRows.length; idx++) {
    final cells = <BoardPoint>[];
    for (var q = -r; q <= r; q++) {
      final p = BoardPoint(q, wallRows[idx]);
      if (game.board.validateBoardPoint(p)) cells.add(p);
    }
    cells.sort((a, b) => idx.isEven ? a.q.compareTo(b.q) : b.q.compareTo(a.q));
    for (final p in cells) {
      if (!game.isPlaceable(p)) continue;
      game.towers[p] = buildTower(TowerType.obstacle, p);
      game.recomputeGuide();
    }
  }
  return game.route.length;
}

const kSimBuilds = {
  TowerType.cannon: [0, 0],
  TowerType.airBlade: [0, 1], // 疾風→亂舞（單分支後 branch 0）
  TowerType.flame: [0, 0],
  TowerType.poison: [1, 0],
  TowerType.freezing: [0, 0],
  TowerType.thunder: [0, 0],
};

/// 無限金幣版：沿路線相鄰格鋪滿升塔。
List<BoardPoint> placeTowersMaxed(TowerDefenseGame game) {
  const order = [
    TowerType.cannon,
    TowerType.airBlade,
    TowerType.poison,
    TowerType.flame,
    TowerType.freezing,
    TowerType.cannon,
    TowerType.thunder,
    TowerType.airBlade,
  ];
  final slots = <BoardPoint>{};
  for (final cell in game.route) {
    for (final d in HexagonDirection.values) {
      slots.add(cell.getNeighbor(d));
    }
  }
  final placed = <BoardPoint>[];
  var i = 0;
  for (final p in slots) {
    if (!game.isPlaceable(p)) continue;
    final type = order[i % order.length];
    final t = buildTower(type, p);
    game.towers[p] = t;
    game.world.add(t);
    game.recomputeGuide();
    final path = kSimBuilds[type]!;
    t.applyUpgrade(kTowerUpgradeTree[type]![path[0]]);
    t.applyUpgrade(kTowerUpgradeTree[type]![path[0]].children[path[1]]);
    placed.add(p);
    i++;
  }
  return placed;
}

/// 經濟版波間建設（有機成長，貼近好的人類打法）：
/// ① 免費障礙物：放在「貼目前路線且最能拉長路線」的格子（免費擴迷宮）。
/// ② 用金幣把塔蓋在同樣「貼路線、最拉長路線」的格子（一塔兼顧牆＋輸出）。
/// ③ 沒新格可蓋或錢不夠蓋塔時，改升級現有塔（朝預定 build）。
void spendOrganic(TowerDefenseGame game) {
  const priority = [
    TowerType.cannon,
    TowerType.airBlade,
    TowerType.flame,
    TowerType.poison,
    TowerType.freezing,
    TowerType.thunder,
  ];

  // ① 免費障礙物用光：每個都放最能拉長路線的貼路線格。
  while (game.freeObstacle.value > 0) {
    final cell = _bestMazeCell(game);
    if (cell == null) break;
    game.towers[cell] = buildTower(TowerType.obstacle, cell);
    game.recomputeGuide();
    game.freeObstacle.value -= 1;
  }

  // ②③ 反覆：能蓋塔就蓋（貼路線最拉長格），否則升級，直到沒錢可用。
  var acted = true;
  while (acted) {
    acted = false;
    // 型別：依已蓋數輪替以求多樣，買不起就退而求其次挑最便宜買得起的。
    final want = priority[
        game.towers.values.where((t) => t.type != TowerType.obstacle).length %
            priority.length];
    TowerType? type;
    if (game.coin.value >= statsOf(want).cost) {
      type = want;
    } else {
      for (final t in priority) {
        if (game.coin.value >= statsOf(t).cost) {
          type = t;
          break;
        }
      }
    }
    if (type != null) {
      final cell = _bestMazeCell(game);
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

/// 貼目前路線、且（試放障礙後）最能拉長路線的可放置空格；無則回 null。
BoardPoint? _bestMazeCell(TowerDefenseGame game) {
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

/// 升級「下一步最便宜且買得起」的塔，朝其預定 build。成功回 true。
bool _upgradeCheapest(TowerDefenseGame game) {
  BoardPoint? bestCell;
  TowerUpgradeNode? bestNode;
  for (final entry in game.towers.entries) {
    final node = _nextNode(entry.value);
    if (node == null || game.coin.value < node.cost) continue;
    if (bestNode == null || node.cost < bestNode.cost) {
      bestNode = node;
      bestCell = entry.key;
    }
  }
  if (bestCell == null) return false;
  return game.upgradeTower(bestCell, bestNode!);
}

TowerUpgradeNode? _nextNode(TowerComponent t) {
  final tree = kTowerUpgradeTree[t.type];
  final path = kSimBuilds[t.type];
  if (tree == null || path == null) return null;
  if (t.chosen.isEmpty) return tree[path[0]];
  if (t.chosen.length == 1) return t.chosen.first.children[path[1]];
  return null;
}

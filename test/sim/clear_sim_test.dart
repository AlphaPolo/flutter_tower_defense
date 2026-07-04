import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/board/hex.dart';
import 'package:tower_defense/game/components/tower/tower_component.dart';
import 'package:tower_defense/game/components/tower/tower_factory.dart';
import 'package:tower_defense/game/tower_defense_game.dart';
import 'package:tower_defense/game/tower_type.dart';

/// 方法 A 通關模擬器：headless 跑「真正的」TowerDefenseGame（真素材、真元件、真
/// update 迴圈），程式化布防後手動驅動 25 波，看是否 gameWon。
///
/// 兩個測試：
///  1. 純戰鬥可行性（無限金幣、迷宮+鋪滿滿升）→ 通關能力上限。
///  2. 真實經濟（150 金 / 3 障礙起手、擊殺滾錢、每波間只買得起的照計畫蓋）
///     → 玩家實際能不能通關。
void main() {
  testWidgets('通關模擬A：純戰鬥可行性（無限金幣、迷宮+滿升）', (tester) async {
    final game = await _boot(tester);
    game.cheat.value = true;

    final mazeLen = _buildMaze(game);
    final placed = _placeTowers(game);
    _tick(game, 10);
    debugPrint('迷宮後 route=$mazeLen 格，放置 ${placed.length} 座塔');

    final report = _runWaves(game, '\n=== A. 純戰鬥可行性 ===\n');
    debugPrint(report);
    expect(game.gameWon.value, isTrue, reason: '迷宮+滿升鋪滿都無法通關 → 過難');
  });

  testWidgets('通關模擬B：真實經濟（150金/3障礙、邊打邊蓋）', (tester) async {
    final game = await _boot(tester);
    // cheat 預設 false → 真實金幣與障礙物限制

    final report = StringBuffer('\n=== B. 真實經濟（有機成長：塔蓋在路線旁兼拉長迷宮）===\n');
    for (var w = 1; w <= TowerDefenseGame.totalWaves; w++) {
      _spendOrganic(game); // 波間建設：買得起就蓋在「貼路線且最能拉長路線」的格子 + 升級
      _tick(game, 5);
      final towers =
          game.towers.values.where((t) => t.type != TowerType.obstacle).length;
      final heartBefore = game.heart.value;

      game.startGame();
      var frames = 0;
      while (game.waveRunning.value &&
          !game.gameOver.value &&
          frames < 60 * 240) {
        game.update(1 / 60);
        frames++;
      }
      report.writeln('Wave ${game.waveNumber.toString().padLeft(2)}: '
          '${game.gameOver.value ? "GAME OVER" : (game.waveRunning.value ? "TIMEOUT" : "cleared")}  '
          'heart=${game.heart.value} 漏${heartBefore - game.heart.value}  '
          '金${game.coin.value} 塔$towers route=${game.route.length}');
      if (game.gameOver.value || game.waveRunning.value) break;
    }
    report.writeln(game.gameWon.value ? '✅ 通關!' : '❌ 未通關');
    debugPrint(report.toString());

    expect(game.gameWon.value, isTrue,
        reason: '真實經濟 + 合理打法都無法通關 → 過難，需調整平衡');
  });

  testWidgets('通關模擬C：真實自動演示元件 AutoPlayer 能通關', (tester) async {
    final game = await _boot(tester);
    game.startAutoDemo(); // 用「產品」的自動演示邏輯（AutoPlayer + autoSpend）
    var frames = 0;
    while (!game.gameWon.value && !game.gameOver.value && frames < 300000) {
      game.update(1 / 60);
      frames++;
    }
    debugPrint('AutoPlayer 結果：${game.gameWon.value ? "✅ 通關" : "❌ GG"} '
        'heart=${game.heart.value} wave=${game.waveNumber}');
    expect(game.gameWon.value, isTrue, reason: '產品自動演示無法通關');
  });

  testWidgets('隨機天然環境不會封死路線', (tester) async {
    final game = TowerDefenseGame(); // withEnvironment 預設 true
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      final sw = Stopwatch()..start();
      while (!game.isLoaded && sw.elapsed < const Duration(seconds: 30)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    expect(game.isLoaded, isTrue);
    expect(game.environment.length, inInclusiveRange(1, 10));
    // 路線仍能從出生點走到主堡（沒被環境封死）。
    expect(game.route.first, game.spawnLocation);
    expect(game.route.last, game.targetLocation);
  });
}

// ───────────────────────── 共用 ─────────────────────────

Future<TowerDefenseGame> _boot(WidgetTester tester) async {
  final game = TowerDefenseGame(withEnvironment: false); // 模擬不產生隨機環境
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    final sw = Stopwatch()..start();
    while (!game.isLoaded && sw.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
  _tick(game, 10);
  expect(game.isLoaded, isTrue, reason: 'game 未在時限內載入');
  return game;
}

void _tick(TowerDefenseGame game, int n) {
  for (var i = 0; i < n; i++) {
    game.update(0);
  }
}

String _runWaves(TowerDefenseGame game, String title) {
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

/// 梳齒迷宮：每隔一列填成牆，isPlaceable 會自動留缺口；相鄰牆左右輪替 → 蛇行長路。
int _buildMaze(TowerDefenseGame game) {
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

const _builds = {
  TowerType.cannon: [0, 0],
  TowerType.airBlade: [0, 1], // 疾風→亂舞（單分支後 branch 0）
  TowerType.flame: [0, 0],
  TowerType.poison: [1, 0],
  TowerType.freezing: [0, 0],
  TowerType.thunder: [0, 0],
};

/// 無限金幣版：沿路線相鄰格鋪滿升塔。
List<BoardPoint> _placeTowers(TowerDefenseGame game) {
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
    final path = _builds[type]!;
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
void _spendOrganic(TowerDefenseGame game) {
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
  final path = _builds[t.type];
  if (tree == null || path == null) return null;
  if (t.chosen.isEmpty) return tree[path[0]];
  if (t.chosen.length == 1) return t.chosen.first.children[path[1]];
  return null;
}

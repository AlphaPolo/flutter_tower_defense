import 'package:flame/components.dart';

/// 連鎖結果的一條「邊」：從 [parent] 連到 [index]。
/// [parent] == -1 → 由起點 origin 直接連出；否則為 positions 的索引（中繼敵人）。
/// 邊的順序即實際連鎖（加入）順序，可直接依序播放視覺。
typedef ChainEdge = ({int parent, int index});

/// 在敵群之間做廣度優先「連鎖」（雷電塔用）。純函式、不依賴遊戲元件，方便測試。
///
/// 從 [origin]（落點 / 被擊中的位置）出發，一跳一跳往外擴散：每一跳只連到與
/// 「當前節點」距離 `<= [maxDistance]` 的對象；候選一律依「到 [origin] 的距離」
/// 由近到遠優先挑選；連到的總數最多 [limit] 個。
///
/// 回傳「邊」清單（含樹狀結構）——視覺依邊繪製才能反映真實的接力路徑，
/// 而不是全部畫回起點的星形。只要索引順序可用 [chainTargets]。
///
/// 距離計算使用 [maxDistance] 的原始單位（與 [positions] 同一座標系）；呼叫端
/// 自行把「格數 × hexRadius」換算成像素距離後傳入，函式本身不依賴棋盤。
List<ChainEdge> chainEdges({
  required Vector2 origin,
  required List<Vector2> positions,
  required double maxDistance,
  required int limit,
}) {
  if (positions.isEmpty || limit <= 0) return const <ChainEdge>[];

  // 候選索引依「到 origin 的距離」由近到遠 → 優先串最近的。
  final candidates = List<int>.generate(positions.length, (i) => i)
    ..sort((a, b) => positions[a]
        .distanceTo(origin)
        .compareTo(positions[b].distanceTo(origin)));

  final visited = <int>{};
  final edges = <ChainEdge>[];
  Vector2 posOf(int i) => i == -1 ? origin : positions[i];
  // 以落點 origin（節點 -1）作為起始節點，第一跳尋找其周圍的敵人。
  var frontier = <int>[-1];

  while (frontier.isNotEmpty) {
    final next = <int>[];
    for (final node in frontier) {
      final nodePos = posOf(node);
      for (final c in candidates) {
        if (visited.length >= limit) break;
        if (visited.contains(c)) continue;
        if (positions[c].distanceTo(nodePos) > maxDistance) continue;
        visited.add(c);
        edges.add((parent: node, index: c));
        next.add(c);
      }
      candidates.removeWhere(visited.contains);
    }
    frontier = next;
  }
  return edges;
}

/// 舊介面：只要「被連到的索引順序」（不需要樹狀結構時用）。
List<int> chainTargets({
  required Vector2 origin,
  required List<Vector2> positions,
  required double maxDistance,
  required int limit,
}) =>
    [
      for (final e in chainEdges(
        origin: origin,
        positions: positions,
        maxDistance: maxDistance,
        limit: limit,
      ))
        e.index
    ];

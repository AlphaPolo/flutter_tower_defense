import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game/components/projectile/chain_targets.dart';

/// 雷電連鎖演算法（純函式）的單元測試。
///
/// 取代舊的 `enemy_finding_test.dart`：那份測的是只存在於測試檔、未被遊戲使用的
/// 草稿；這份直接測雷電塔實際呼叫的 [chainTargets]。
void main() {
  Vector2 v(double x, double y) => Vector2(x, y);

  group('chainTargets', () {
    test('一直線等距、上限夠大 → 全部連鎖（由近到遠）', () {
      final pos = [v(1, 0), v(2, 0), v(3, 0), v(4, 0), v(5, 0)];
      final r = chainTargets(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 1.0,
        limit: 99,
      );
      expect(r, [0, 1, 2, 3, 4]);
    });

    test('limit 限制最多串聯數，且取最近的 N 個', () {
      final pos = [v(1, 0), v(2, 0), v(3, 0), v(4, 0), v(5, 0)];
      Object run(int limit) => chainTargets(
            origin: v(0, 0),
            positions: pos,
            maxDistance: 1.0,
            limit: limit,
          );
      expect(run(3), [0, 1, 2]);
      expect(run(2), [0, 1]);
      expect(run(1), [0]);
    });

    test('斷層：相鄰間距超過 maxDistance 就中斷', () {
      // 0→1→2→3 每段距離 1；x=6、7 與最近的 x=3 相距 3，連不過去。
      final pos = [v(1, 0), v(2, 0), v(3, 0), v(6, 0), v(7, 0)];
      final r = chainTargets(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 1.0,
        limit: 99,
      );
      expect(r, [0, 1, 2], reason: '間隔太遠，連鎖在 x=3 之後中斷');
    });

    test('對角線、距離夠遠時 → limit 決定串聯數（取最近的）', () {
      // 還原舊測試的場景，但用「正確」的預期：limit 才是決定 3 個的原因。
      final pos = [v(1, 1), v(2, 2), v(3, 3), v(4, 4), v(5, 5)];
      Object run(int limit) => chainTargets(
            origin: v(0, 0),
            positions: pos,
            maxDistance: 10,
            limit: limit,
          );
      expect(run(3), [0, 1, 2]);
      expect(run(2), [0, 1]);
      expect(run(1), [0]);
    });

    test('origin 周圍 maxDistance 內沒有敵人 → 回空', () {
      final pos = [v(3, 3), v(4, 4), v(5, 5)]; // 最近距 origin ≈ 4.24
      final r = chainTargets(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 2,
        limit: 99,
      );
      expect(r, isEmpty);
    });

    test('左右兩側都會被連鎖到', () {
      final pos = [v(-2, 0), v(-1, 0), v(1, 0), v(2, 0)];
      final r = chainTargets(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 1.0,
        limit: 99,
      );
      // 由近到遠：(-1)、(1) 同距 1，(−2)、(2) 同距 2；用集合比對避免 tie 排序問題。
      expect(r.toSet(), {0, 1, 2, 3});
      expect(r.length, 4);
    });

    test('邊結構：遠敵的 parent 必須是中繼節點、不是起點', () {
      // 0—1—2 一直線間距 1：1 要經過 0、2 要經過 1 接力連上。
      final pos = [v(1, 0), v(2, 0), v(3, 0)];
      final edges = chainEdges(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 1.0,
        limit: 99,
      );
      expect(edges, [
        (parent: -1, index: 0), // 起點直連最近的
        (parent: 0, index: 1), // 經 0 中繼
        (parent: 1, index: 2), // 經 1 中繼
      ]);
    });

    test('邊結構：起點周圍多個近敵都直連起點（同一跳）', () {
      final pos = [v(-1, 0), v(1, 0)];
      final edges = chainEdges(
        origin: v(0, 0),
        positions: pos,
        maxDistance: 1.0,
        limit: 99,
      );
      expect({for (final e in edges) e.index: e.parent}, {0: -1, 1: -1});
    });

    test('邊界：空清單 / limit<=0 → 回空', () {
      expect(
        chainTargets(origin: v(0, 0), positions: [], maxDistance: 5, limit: 5),
        isEmpty,
      );
      expect(
        chainTargets(
          origin: v(0, 0),
          positions: [v(1, 0)],
          maxDistance: 5,
          limit: 0,
        ),
        isEmpty,
      );
    });
  });
}

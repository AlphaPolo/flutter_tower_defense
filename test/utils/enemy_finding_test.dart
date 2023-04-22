import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';

List<Offset> findConnectedEnemy(Offset center, List<Offset> coords, double distance, [int? limit]) {
  final visited = <Offset>{};
  final enemies = coords;
  Queue<Offset> frontier = Queue<Offset>()..add(center);

  bool isInRange(Offset a, Offset b) => (a - b).distance <= distance;

  while(frontier.isNotEmpty) {
    final nextFrontier = <Offset>[];
    for (final e in frontier) {
      enemies.where((enemy) => isInRange(enemy, e))
        .takeWhile((value) => limit == null || visited.length < limit)
        .forEach((enemy) {
          visited.add(enemy);
          nextFrontier.add(enemy);
      });
      enemies.removeWhere(visited.contains);
    }
    frontier.clear();
    frontier.addAll(nextFrontier);
  }
  return visited.toList();
}

void main() {
  test('連鎖所有的敵人', () {
    const center = Offset(0, 0);
    List<Offset> coords = [
      const Offset(1, 0),
      const Offset(2, 0),
      const Offset(3, 0),
      const Offset(4, 0),
      const Offset(5, 0),
    ];
    final result = findConnectedEnemy(center, coords, 1);
    expect(result.length, 5);
  });

  // 定义测试用例1
  group('test on x axis with different distances', () {
      const center = Offset(0, 0);

      test('Test 左與右', () {
        final enemies = [
          const Offset(-2, 0),
          const Offset(-1, 0),
          const Offset(1, 0),
          const Offset(2, 0),
          const Offset(3, 0),
        ];
        final result = findConnectedEnemy(center, enemies, 1);
        expect(result.length, 5);
      });

      test('Test 斷層', () {
        final enemies = [
          const Offset(-3, 0),
          const Offset(-1, 0),
          const Offset(1, 0),
          const Offset(2, 0),
          const Offset(5, 0),
          const Offset(6, 0),
        ];
        final result = findConnectedEnemy(center, enemies, 1);
        expect(result.length, 3, reason: '因為間格太遠觸碰不到');
        expect(result, [
          const Offset(-1, 0),
          const Offset(1, 0),
          const Offset(2, 0),
        ]);
      });

  });

  // 定义测试用例2
  test('Test findConnectedEnemy with same distance', () {
    const center = Offset(0, 0);
    final enemies = [
      const Offset(1, 1),
      const Offset(2, 2),
      const Offset(3, 3),
      const Offset(4, 4),
      const Offset(5, 5),
    ];

    // 测试距离为3时的情况
    final result1 = findConnectedEnemy(center, enemies, 3);
    expect(result1, [const Offset(1, 1), const Offset(2, 2), const Offset(3, 3)]);

    // 测试距离为2时的情况
    final result2 = findConnectedEnemy(center, enemies, 2);
    expect(result2, [const Offset(1, 1), const Offset(2, 2), const Offset(3, 3)]);

    // 测试距离为1时的情况
    final result3 = findConnectedEnemy(center, enemies, 1);
    expect(result3, [const Offset(1, 1), const Offset(2, 2), const Offset(3, 3)]);
  });

  // 定义测试用例3
  test('Test findConnectedEnemy with no enemies within distance', () {
    const center = Offset(0, 0);
    final enemies = [
      const Offset(3, 3),
      const Offset(4, 4),
      const Offset(5, 5),
    ];

    // 测试距离为2时没有敌人在范围内的情况
    final result1 = findConnectedEnemy(center, enemies, 2);
    expect(result1, []);

    // 测试距离为3时没有敌人在范围内的情况
    final result2 = findConnectedEnemy(center, enemies, 3);
    expect(result2, []);
  });
}
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/bool_extension.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/model/projectile/projectile.dart';

import '../../manager/game_manager.dart';
import '../../utils/game_utils.dart';
import '../enemy/enemy.dart';

class ThunderProjectile extends Projectile {

  ThunderProjectile(
    super.damage,
    super.position,
    super.direction,
    super.speed,
    this.chainLimit, {
    this.chainDistance = 2,
  });

  double chainDistance;
  final int chainLimit;
  List<Offset>? bindEnemies;

  @override
  void tick(GameManager manager, int timeDelta) {
    clock += timeDelta;

    if (isDead) return;
    if (isChainState) return updateChainState();
    if (!atGoal()) return;

    /// 到目標點後狀態切換
    position = target?.renderOffset ?? goal!;

    /// 連結所有可以到達的目標並且降低跑速
    bindEnemies = chainEnemies(manager, target!)
                    // .map((e) => e.renderOffset!)
                    .fold<List<Offset>>([], (list, enemy) {
                      enemy.status = enemy.status.copyWith(speed: enemy.status.speed * 0.5);
                      // list.add(enemy.renderOffset!);
                      final offset = enemy.renderOffset! - position;
                      list.add(offset);
                      return list;
                    });

    lifeTime = 1000;
    clock = 0;
  }

  void updateChainState() {
    if(clock >= lifeTime) {
      isDead = true;
    }
  }

  bool atGoal() {
    return clock >= lifeTime;
  }

  /// 下個目標是否可以被連結
  bool isValid(Enemy enemy) {
    return !enemy.isDead && !enemy.isGoal;
  }

  Set<Enemy> chainEnemies(GameManager manager, Enemy from) {
    final frontier = Queue<Enemy>()..add(from);
    final visited = <Enemy>{};

    final enemies = GameUtils.getEnemiesHasRenderOffset(manager)
                            .where(isValid)
                            .whereNot(visited.contains)
                            .sortedByCompare(
                              (e) => (e.renderOffset! - position).distance,
                              (a, b) => a.compareTo(b),
                            );

    final board = manager.board;
    if(board == null) return {};

    bool isInRange(Enemy a, Enemy b) => GameUtils.isInsideRange(board, a.renderOffset! - b.renderOffset!, chainDistance);

    while(frontier.isNotEmpty) {
      final nextFrontier = <Enemy>[];
      for (final e in frontier) {
        enemies.where((enemy) => isInRange(enemy, e))
            .takeWhile((value) => visited.length < chainLimit)
            .forEach((enemy) {
          visited.add(enemy);
          nextFrontier.add(enemy);
        });
        enemies.removeWhere(visited.contains);
      }
      frontier.clear();
      frontier.addAll(nextFrontier);
    }

    return visited;
  }

  bool get isChainState => (bindEnemies?.isNotEmpty).isTrue;

  @override
  Widget render() {
    if(!isChainState) {
      return buildThunderBullet();
    }
    else {
      return buildConnect();
    }
  }

  Widget buildThunderBullet() {
    return TweenAnimationBuilder(
      key: ObjectKey(this),
      tween: RectTween(
        begin: Rect.fromCircle(center: position, radius: 5),
        end: Rect.fromCircle(center: goal!, radius: 5),
      ),
      duration: lifeTime.ms,
      builder: (context, value, child) {
        return Positioned.fromRect(rect: value!, child: child!);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.yellow,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget buildConnect() {
    final lightingEffect = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.yellow, width: 2),
      ),
    );

    return Positioned.fromRect(
      rect: Rect.fromCircle(center: position, radius: 8),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ...?bindEnemies?.mapIndexed((index, e) {
            /// 增加一點延遲效果
            if(clock < index * 20) return const SizedBox.shrink();
            return TweenAnimationBuilder(
              key: ObjectKey(e),
              duration: lifeTime.ms,
              tween: Tween<double>(begin: 8, end: 2),
              curve: const SawTooth(4),
              builder: (context, value, child) {
                return Positioned.fromRect(
                  rect: Rect.fromCircle(center: e, radius: value),
                  child: child!,
                );
              },
              child: lightingEffect,
            );
          }),
        ],
      )
    );
  }
}

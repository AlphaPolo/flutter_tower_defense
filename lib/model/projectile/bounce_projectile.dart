import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tower_defense/extension/duration_extension.dart';
import 'package:tower_defense/model/projectile/projectile.dart';
import 'package:tower_defense/utils/game_utils.dart';

import '../../manager/game_manager.dart';
import '../enemy/enemy.dart';

class BounceProjectile extends Projectile {
  BounceProjectile(
    super.damage,
    super.position,
    super.direction,
    super.speed,
    this.bounceTime,
  );

  final int bounceTime;
  int counter = 0;

  final Set<Enemy> hasVisitedEnemy = {};
  // @override
  // void init(GameManager manager) {
  //   super.init(manager);
  //   lifeTime
  // }

  @override
  void tick(GameManager manager, int clock) {
    this.clock += clock;

    if(isDead) return;
    if(!atGoal()) return;

    /// 到目標點後將自己的position設置成目標點
    position = goal!;
    hasVisitedEnemy.add(target!);

    /// 不可再彈跳了
    if(counter >= bounceTime) {
      isDead = true;
      return;
    }


    /// 尋找下個距離內的目標
    counter++;
    final nextEnemy = findNext(manager);

    /// 如果距離內沒有目標
    if(nextEnemy == null) {
      isDead = true;
      return;
    }

    target = nextEnemy;
    goal = nextEnemy.renderOffset!;
    lifeTime = calculatorFlyingTime(position, goal!, speed * 2);
    this.clock = 0;
  }

  bool atGoal() {
    return clock >= lifeTime;
  }

  /// 下個目標是否可以被連結
  bool cantConnectEnemy(Enemy enemy) {
    return hasVisitedEnemy.contains(enemy) ||
      enemy.isDead ||
      enemy.isGoal;
  }

  Enemy? findNext(GameManager manager) {
    final enemies = GameUtils.getEnemiesHasRenderOffset(manager)
        .whereNot(cantConnectEnemy)
        .map((e) => GameUtils.toOffsetEnemyTuple(e, position))
        .where((e) => GameUtils.isInsideRange(manager.board!, e.item1, 5));

    final enemy = minBy(enemies, (enemy) => enemy.item1.distance)?.item2;
    return enemy;
  }

  @override
  Widget render() {

    return TweenAnimationBuilder(
        key: ObjectKey(this),
        tween: RectTween(
          begin: Rect.fromCircle(center: position, radius: 5),
          end: Rect.fromCircle(center: goal!, radius: 5),
        ),
        duration: lifeTime.ms,
        builder: (BuildContext context, Rect? value, Widget? child) {
          return Positioned.fromRect(rect: value!, child: child!);
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.yellow,
            shape: BoxShape.circle,
          ),
        )
    );
  }

}
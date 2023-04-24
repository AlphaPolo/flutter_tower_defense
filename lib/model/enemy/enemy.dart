import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:tower_defense/extension/kotlin_like_extensions.dart';
import 'package:tower_defense/manager/game_manager.dart';
import 'package:tower_defense/model/effects/base_effect.dart';
import 'package:tower_defense/widget/game/board/board_painter.dart';

import '../../utils/game_utils.dart';
/// 假設怪物的速度是1，那麼他要走完一格必須花費16ms * 60的時間也就是60幀
///
/// 假設怪物的速度是2，那麼他每一幀的完成度是2，所以他只需要花費30幀的時間
const speedComplete = 16 * 60;

class Enemy {

  late GameManager manager;
  BoardPoint currentLocation;
  BoardPoint? goalLocation;
  Offset? renderOffset;
  EnemyStatus status;
  EnemyStatus? afterEffects;

  int id = 0;
  int clock = 0;
  bool _dead = false;
  bool _goal = false;
  List<BaseEffect> effects = [];



  late Iterator<BoardPoint> pathFinder;
  late Iterator<Offset> bodyMover;


  Enemy(this.currentLocation, this.status);

  void init(GameManager manager) {
    this.manager = manager;
    pathFinder = pathGenerator(manager, this).iterator;
  }

  void tick(GameManager manager, int timeDelta) {
    clock = timeDelta;

    if(isDead) return;

    afterEffects = tickEffects(manager, timeDelta, status);

    if(goalLocation == null) {
      if(pathFinder.moveNext()) {
        goalLocation = pathFinder.current;
        bodyMover = renderGenerator(this, currentLocation, goalLocation!).iterator;
      }
      else {
        return;
      }
    }

    if(bodyMover.moveNext()) {
      renderOffset = bodyMover.current;
    }
    else {
      currentLocation = goalLocation!;
      goalLocation = null;
      if(currentLocation == manager.targetLocation) {
        _goal = true;
      }
    }

  }

  void dealDamage(double damage) {
    if(isDead) return;
    status = status.sub(hp: damage);

    if(status.currentHp <= 0) _dead = true;
  }

  bool get isDead {
    return _dead;
  }

  bool get isGoal {
    return _goal;
  }



  Iterable<Offset> renderGenerator(Enemy enemy, BoardPoint from, BoardPoint to) sync* {
    final begin = GameUtils.toOffset(from);
    final goal = GameUtils.toOffset(to);

    double complete = 0;
    while(complete < speedComplete) {
      // if(enemy.id == 1) {
      //   print('progress: ${complete/speedComplete}');
      // }
      final current = Offset.lerp(begin, goal, complete / speedComplete)!;
      yield current;
      complete += enemy.clock * (enemy.afterEffects ?? enemy.status).speed;
    }
  }

  Enemy copyWith({
    BoardPoint? currentLocation,
    EnemyStatus? status,
  }) {
    return Enemy(
      currentLocation ?? this.currentLocation,
      status ?? this.status,
    );
  }

  void addEffect(BaseEffect effect) {
    effect.attach(manager, this);
    effects.add(effect);
    effects.sort();
  }

  EnemyStatus tickEffects(GameManager manager, int clock, EnemyStatus origin) {
    bool dirty = false;
    EnemyStatus afterEffects = origin;
    for(final effect in effects) {
      effect.tick(manager, clock);
      afterEffects = effect.calc(manager, afterEffects);
      if(effect.dead) dirty = true;
    }
    /// 清理垃圾
    if(dirty) {
      effects.removeWhere((effect) {
        if(effect.dead) effect.onEnd(manager, this);
        return effect.dead;
      });
    }

    return afterEffects;
  }
}

Iterable<BoardPoint> pathGenerator(GameManager gameManager, Enemy enemy) sync* {

  while(enemy.goalLocation != gameManager.targetLocation) {
    final direction = gameManager.guide[enemy.currentLocation];
    if(direction == null) return;
    yield enemy.currentLocation.getNeighbor(direction);
  }
}

/// 可能之後讓移動更加圓滑
class Bezier {

  static Offset getPoint(Offset a, Offset b, Offset c, double t) {
    double r = 1.0 - t;
    return (a * r * r) + (b * 2.0 * r * t) + (c * t * t);
  }
}

class EnemyStatus {
  final double totalHp;
  final double currentHp;
  final double speed;

  const EnemyStatus({
    required this.totalHp,
    required this.currentHp,
    required this.speed,
  });

  EnemyStatus copyWith({
    double? totalHp,
    double? currentHp,
    double? speed,
  }) {
    return EnemyStatus(
      totalHp: totalHp ?? this.totalHp,
      currentHp: currentHp ?? this.currentHp,
      speed: speed ?? this.speed,
    );
  }

  EnemyStatus add({
    double? hp,
    double? speed,
  }) {
    return copyWith(
      currentHp: hp?.let((x) => currentHp + x),
      speed: speed?.let((x) => this.speed + x),
    );
  }

  EnemyStatus sub({
    double? hp,
    double? speed,
  }) {
    return copyWith(
      currentHp: hp?.let((x) => currentHp - x),
      speed: speed?.let((x) => this.speed - x),
    );
  }
}


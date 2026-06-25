import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../board/hex.dart';
import '../../tower_defense_game.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';
import '../projectile/projectile.dart';

/// 防禦塔基底（isometric 版）。瞄準/射程在 top-down 邏輯座標計算；繪製用
/// 預先渲染好的 isometric 塔素材，放在格子的螢幕座標上，依螢幕 y 排序深度。
class TowerComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  TowerComponent(this.type, this.location);

  final TowerType type;
  final BoardPoint location;

  double direction = 0;
  EnemyComponent? target;
  double prepareShoot = 0;

  /// top-down 邏輯位置。
  final Vector2 logicalPos = Vector2.zero();

  TowerStats get stats => statsOf(type);
  int get cost => stats.cost;
  double get range => stats.range;
  double get damage => stats.damage;
  int get fireCD => stats.fireCD;

  Sprite get sprite => game.towerSprites[type]!;

  /// 障礙物用較大的縮放（石頭原始很小）。
  double get spriteScale => 1.0;

  @override
  void onMount() {
    super.onMount();
    logicalPos.setFrom(game.boardToLogical(location));
    anchor = Anchor.center;
    size = sprite.srcSize * spriteScale;
    position.setFrom(game.boardToScreen(location));
    priority = position.y.round();
  }

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;

    target ??= game.nearestEnemy(logicalPos, range);
    final t = target;
    if (t == null) return;

    if (t.isDead || !t.isMounted) {
      target = null;
      return;
    }
    final diff = t.logicalPos - logicalPos;
    if (!game.isInsideRange(diff, range)) {
      target = null;
      return;
    }
    direction = atan2(diff.y, diff.x);
    attemptShoot(t);
  }

  void attemptShoot(EnemyComponent enemy) {
    if (prepareShoot > 0) return;
    final projectile = createProjectile(enemy);
    if (projectile != null) game.world.add(projectile);
    prepareShoot = fireCD.toDouble();
  }

  ProjectileComponent? createProjectile(EnemyComponent enemy) {
    return NormalProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1,
      target: enemy,
    );
  }

  /// 砲口（邏輯座標）。
  Vector2 muzzle([double dist = 32]) =>
      logicalPos + Vector2(cos(direction), sin(direction)) * dist;

  @override
  void render(Canvas canvas) {
    sprite.render(canvas, size: size);
  }
}

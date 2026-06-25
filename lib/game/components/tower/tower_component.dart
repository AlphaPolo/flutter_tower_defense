import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../board/hex.dart';
import '../../tower_defense_game.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';
import '../projectile/projectile.dart';

/// 防禦塔基底。預設行為等同舊版 BuildingModel：鎖定範圍內最近的敵人、
/// 轉向、依冷卻時間開火。雷電塔直接沿用這套行為，其他塔覆寫 update。
class TowerComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  TowerComponent(this.type, this.location) : super(priority: 10);

  final TowerType type;
  final BoardPoint location;

  double direction = 0;
  EnemyComponent? target;
  double prepareShoot = 0;

  TowerStats get stats => statsOf(type);
  int get cost => stats.cost;
  double get range => stats.range;
  double get damage => stats.damage;
  int get fireCD => stats.fireCD;

  @override
  void onMount() {
    super.onMount();
    position = game.boardToWorld(location);
  }

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;

    target ??= game.nearestEnemy(position, range);
    final t = target;
    if (t == null) return;

    if (t.isDead || !t.isMounted) {
      target = null;
      return;
    }
    final diff = t.position - position;
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

  /// 砲口位置（從塔中心沿 direction 方向偏移）。
  Vector2 muzzle([double dist = 32]) =>
      position + Vector2(cos(direction), sin(direction)) * dist;

  @override
  void render(Canvas canvas) {
    drawHexBase(canvas, Colors.blueGrey);
    renderTurret(canvas);
  }

  /// 子型別覆寫以畫出各自的砲管 / 圖示。
  void renderTurret(Canvas canvas) {}

  // ── 繪圖工具 ─────────────────────────────────────────────
  Path hexPath(double r) {
    final h = r * sqrt(3) / 2;
    return Path()
      ..moveTo(0, -r)
      ..lineTo(h, -r / 2)
      ..lineTo(h, r / 2)
      ..lineTo(0, r)
      ..lineTo(-h, r / 2)
      ..lineTo(-h, -r / 2)
      ..close();
  }

  void drawHexBase(Canvas canvas, Color color) {
    final r = game.board.hexagonRadius * 0.7;
    canvas.drawPath(hexPath(r), Paint()..color = color);
  }

  void drawTurret(
    Canvas canvas, {
    required double w,
    required double h,
    required Color color,
  }) {
    canvas
      ..save()
      ..rotate(direction)
      ..drawRect(Rect.fromLTWH(0, -h / 2, w, h), Paint()..color = color)
      ..restore();
  }

  void drawIcon(
    Canvas canvas,
    IconData icon, {
    required double size,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}

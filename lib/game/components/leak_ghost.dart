import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../tower_defense_game.dart';
import 'enemy_kind.dart';

/// 敵人抵達主堡後的「替身」淡出效果：**純視覺**，不進 `game.enemies`，因此塔/陷阱/
/// 子彈都不會鎖定或命中它。維持走路動畫、在原地淡出，播完自動移除。
class LeakGhostComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  LeakGhostComponent({
    required this.kind,
    required Vector2 screenPos,
    required this.faceLeft,
    required double animT,
  })  : _animT = animT,
        super(anchor: Anchor.center) {
    position.setFrom(screenPos);
  }

  final EnemyKind kind;
  final bool faceLeft;
  double _animT; // 續播走路動畫
  double _age = 0;
  static const double _dur = 0.4;

  @override
  void onMount() {
    super.onMount();
    priority = position.y.round();
  }

  @override
  void update(double dt) {
    _age += dt;
    _animT += dt; // 維持走路動畫
    if (_age >= _dur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fade = (1 - _age / _dur).clamp(0.0, 1.0);
    final s = game.iso.scaleX;
    final img = game.enemySheets[kind.id];
    if (img != null) {
      final size = game.board.hexagonRadius * s * 1.9 * kind.sizeMul;
      final frame = (_animT / 0.11).floor() % kind.frames;
      final src = Rect.fromLTWH(
          frame * kind.frameSize, 0, kind.frameSize, kind.frameSize);
      final centerY = size * (0.62 - kind.footFrac);
      final dst =
          Rect.fromCenter(center: Offset(0, centerY), width: size, height: size);
      canvas.save();
      if (faceLeft) canvas.scale(-1, 1);
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..filterQuality =
              kind.pixel ? FilterQuality.none : FilterQuality.medium
          ..colorFilter =
              ColorFilter.mode(Colors.white.withOpacity(fade), BlendMode.modulate),
      );
      canvas.restore();
    } else {
      final r = game.board.hexagonRadius * 0.3 * kind.sizeMul * s;
      canvas.drawCircle(
          Offset.zero, r, Paint()..color = kind.color.withOpacity(fade));
    }
  }
}

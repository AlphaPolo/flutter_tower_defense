import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../tower_defense_game.dart';

/// 一次性播放的爆炸動畫（Tiny Swords 素材 explosion.png，10 幀）。
/// 播完自動移除；畫在最上層，蓋過敵人與塔。
class ExplosionComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  ExplosionComponent({required Vector2 screenPos, required this.diameter}) {
    position = screenPos;
    anchor = Anchor.center;
    // 與敵人/塔同層、依落點螢幕 y 深度排序（+1 蓋過同層敵人），與滾木一致：
    // 前方(較大 y)的塔會擋住爆炸，不再無腦畫最上層。
    priority = screenPos.y.round() + 1;
  }

  final double diameter;

  static const int _frames = 10;
  static const double _cell = 192;
  static const double _frameDur = 0.045; // 每幀秒數（總長約 0.45s）
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _frames * _frameDur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final frame = (_t / _frameDur).floor().clamp(0, _frames - 1);
    final src = Rect.fromLTWH(frame * _cell, 0, _cell, _cell);
    final dst =
        Rect.fromCenter(center: Offset.zero, width: diameter, height: diameter);
    canvas.drawImageRect(
      game.explosionSheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

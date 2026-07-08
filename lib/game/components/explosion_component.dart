import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../tower_defense_game.dart';

/// 一次性播放的爆炸動畫（Tiny Swords 素材 explosion.png，10 幀）。
/// 同時畫出「傷害範圍環」（貼地 iso 橢圓，隨爆炸淡出）幫助觀察。
/// 播完自動移除；依落點螢幕 y 深度排序（+1 蓋過同層敵人），與滾木一致。
class ExplosionComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  ExplosionComponent({
    required Vector2 screenPos,
    required this.diameter,
    required this.blastLogical,
  }) {
    position = screenPos;
    anchor = Anchor.center;
    priority = screenPos.y.round() + 1;
  }

  final double diameter; // 爆炸圖顯示直徑（螢幕px）
  final double blastLogical; // 傷害半徑（邏輯單位，用來畫範圍環）

  static const int _frames = 10;
  static const double _cell = 192;
  static const double _frameDur = 0.045; // 每幀秒數（總長約 0.45s）
  double _t = 0;

  @override
  void onMount() {
    super.onMount();
    GameAudio.world('explosion', position, volume: 0.85, throttleMs: 90);
  }

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= _frames * _frameDur) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final fade = (1 - _t / (_frames * _frameDur)).clamp(0.0, 1.0);

    // 傷害範圍環（貼地）：用 iso 地面基向量畫出邏輯半徑 blastLogical 的圓。
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final ring = Path();
    for (var i = 0; i <= 32; i++) {
      final a = i / 32 * 2 * pi;
      final v = ax * (blastLogical * cos(a)) + ay * (blastLogical * sin(a));
      i == 0 ? ring.moveTo(v.x, v.y) : ring.lineTo(v.x, v.y);
    }
    ring.close();
    _ringFillPaint.color = Colors.orange.withValues(alpha: 0.15 * fade);
    canvas.drawPath(ring, _ringFillPaint);

    // 爆炸圖
    final frame = (_t / _frameDur).floor().clamp(0, _frames - 1);
    final src = Rect.fromLTWH(frame * _cell, 0, _cell, _cell);
    final dst =
        Rect.fromCenter(center: Offset.zero, width: diameter, height: diameter);
    canvas.drawImageRect(game.explosionSheet, src, dst, _imgPaint);

    // 範圍環外框畫在爆炸圖上方，看得清楚邊界。
    _ringStrokePaint
      ..strokeWidth = 2.5 * s
      ..color = Colors.orangeAccent.withValues(alpha: 0.75 * fade);
    canvas.drawPath(ring, _ringStrokePaint);
  }

  // 每幀重用的 paint（alpha 隨 fade 改設定、不重新配置）。
  static final Paint _ringFillPaint = Paint();
  static final Paint _ringStrokePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _imgPaint = Paint()..filterQuality = FilterQuality.medium;
}

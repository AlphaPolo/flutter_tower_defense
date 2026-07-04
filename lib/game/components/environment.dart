import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../board/hex.dart';
import '../tower_defense_game.dart';

final _rnd = Random();

/// 每場隨機佈置的天然環境種類。
/// [blocks]＝是否阻擋敵人路線（也一律不可在上面建塔，見 game.isPlaceable）。
enum EnvType {
  boulder(blocks: true, label: '巨石', desc: '天然巨石，單純阻擋敵人前進。'),
  pond(blocks: true, label: '水池', desc: '無法跨越的水池，阻擋路線。'),
  woods(blocks: true, label: '密林', desc: '茂密樹林，阻擋路線。'),
  mud(blocks: false, label: '泥沼', desc: '不阻擋路線；經過的敵人會被減速。'),
  thorns(blocks: false, label: '荊棘', desc: '不阻擋路線；經過的敵人持續受到少量傷害。');

  const EnvType(
      {required this.blocks, required this.label, required this.desc});
  final bool blocks;
  final String label;
  final String desc;
}

/// 一格天然環境的顯示元件（程式繪製佔位外觀）。
/// 站立物(巨石/密林)依螢幕 y 深度排序；平面物(水池/泥沼/荊棘)貼地、畫在單位之下。
class EnvComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  EnvComponent(this.envType, this.location);

  final EnvType envType;
  final BoardPoint location;
  late final int _variant = _rnd.nextInt(game.obstacleSprites.length);
  double _t = 0; // 水面 shader 的動畫時間

  bool get _standing => envType == EnvType.boulder || envType == EnvType.woods;

  @override
  void update(double dt) {
    if (envType == EnvType.pond) _t += dt;
  }

  @override
  void onMount() {
    super.onMount();
    anchor = Anchor.center;
    position.setFrom(game.boardToScreen(location));
    final s = game.iso.scaleX;
    size = Vector2.all(game.board.hexagonRadius * 2 * s);
    priority = _standing ? position.y.round() : -2; // 平面物畫在單位之下
  }

  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final r = game.board.hexagonRadius;
    final foot = Offset(size.x / 2, size.y / 2);
    switch (envType) {
      case EnvType.boulder:
        game.obstacleSprites[_variant].render(canvas, size: size);
        break;
      case EnvType.woods:
        _flat(canvas, foot, const Color(0x553B5323));
        for (final dx in const [-0.35, 0.08, 0.4]) {
          final c = foot.translate(dx * r * s, -0.15 * r * s);
          canvas
            ..drawRect(
                Rect.fromCenter(
                    center: c.translate(0, 7 * s),
                    width: 2.5 * s,
                    height: 8 * s),
                Paint()..color = const Color(0xFF5D4037))
            ..drawCircle(c, 7.5 * s, Paint()..color = const Color(0xFF2E7D32))
            ..drawCircle(c.translate(-2 * s, -2 * s), 3 * s,
                Paint()..color = const Color(0xFF43A047));
        }
        break;
      case EnvType.pond:
        final prog = game.waterProgram;
        if (prog != null) {
          // 動態水面 fragment shader，剪裁成貼地橢圓。
          final shader = prog.fragmentShader()
            ..setFloat(0, size.x)
            ..setFloat(1, size.y)
            ..setFloat(2, _t);
          canvas
            ..save()
            ..clipPath(_groundPath(foot))
            ..drawRect(
                Offset.zero & Size(size.x, size.y), Paint()..shader = shader)
            ..restore();
        } else {
          // 退回：平面水池 + 反光。
          _flat(canvas, foot, const Color(0xCC1E88E5));
          canvas.drawOval(
            Rect.fromCenter(
                center: foot.translate(-3 * s, -2 * s),
                width: 0.7 * r * s,
                height: 0.35 * r * s),
            Paint()..color = const Color(0x88BBDEFB),
          );
        }
        break;
      case EnvType.mud:
        _flat(canvas, foot, const Color(0xCC5D4037));
        break;
      case EnvType.thorns:
        _flat(canvas, foot, const Color(0xAA33691E));
        final p = Paint()
          ..color = const Color(0xFF9CCC65)
          ..strokeWidth = 1.8 * s
          ..strokeCap = StrokeCap.round;
        for (final off in const [-0.35, -0.1, 0.15, 0.4]) {
          final b = foot.translate(off * r * s, 0.15 * r * s);
          canvas.drawLine(b, b.translate(1 * s, -8 * s), p);
        }
        break;
    }
  }

  /// 貼地的橢圓路徑（用 iso 地面基向量，讓它躺在地面角度上）。
  Path _groundPath(Offset foot) {
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final r = game.board.hexagonRadius * 0.72;
    final path = Path();
    for (var i = 0; i <= 24; i++) {
      final a = i / 24 * 2 * pi;
      final d = ax * (r * cos(a)) + ay * (r * sin(a));
      final pt = Offset(foot.dx + d.x, foot.dy + d.y);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  /// 用貼地橢圓填一塊顏色。
  void _flat(Canvas canvas, Offset foot, Color col) =>
      canvas.drawPath(_groundPath(foot), Paint()..color = col);
}

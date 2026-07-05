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

  // ── 水面倒影可調參數（Route B）──────────────────────────────
  static const double _reflAlpha = 0.42; // 倒影整體不透明度
  static const double _reflScaleY = 0.9; // 垂直壓縮（水面透視感）
  static const double _reflSway = 2.5; // 隨水波左右晃動幅度(px)
  static const Color _reflTint = Color(0x552A6FB0); // 藍色調（倒影用，維持原設定）
  // 倒影往水池中心拉近的比例：0＝落在物件腳下(常被裁掉、露出少)，1＝拉到水池
  // 正中央。離水池越遠的物件被拉越多，正好補償「後方物件倒影跑到池外」。
  static const double _reflPull = 0.3;
  // 水池外型不規則程度：0＝正圓，越大邊緣越有機（各池外型不同但固定）。
  static const double _pondWobble = 0.05;

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
            ..clipPath(_groundPath(foot, wobble: _pondWobble))
            ..drawRect(
                Offset.zero & Size(size.x, size.y), Paint()..shader = shader)
            ..restore();
        } else {
          // 退回：平面水池 + 反光。
          _flat(canvas, foot, const Color(0xCC1E88E5), wobble: _pondWobble);
          canvas.drawOval(
            Rect.fromCenter(
                center: foot.translate(-3 * s, -2 * s),
                width: 0.7 * r * s,
                height: 0.35 * r * s),
            Paint()..color = const Color(0x88BBDEFB),
          );
        }
        _renderReflections(canvas, foot);
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

  /// 貼地的路徑（用 iso 地面基向量，讓它躺在地面角度上）。
  /// [wobble]>0 時把半徑依角度做週期擾動 → 有機、非正圓的外型；用 location 當
  /// 種子，讓每個水池長得不一樣但每幀穩定（不會抖）。
  Path _groundPath(Offset foot, {double wobble = 0}) {
    final ax = game.iso.axisX;
    final ay = game.iso.axisY;
    final r = game.board.hexagonRadius * 0.72;
    final seed = location.q * 2.7 + location.r * 1.3;
    const steps = 40;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * pi;
      final k = wobble == 0
          ? 1.0
          : 1.0 +
              wobble * (sin(a * 3 + seed) * 0.6 + sin(a * 5 - seed * 1.7) * 0.4);
      final rr = r * k;
      final d = ax * (rr * cos(a)) + ay * (rr * sin(a));
      final pt = Offset(foot.dx + d.x, foot.dy + d.y);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  /// 水面倒影：把水池「後方」相鄰的塔上下翻轉、藍調、淡出、隨水波輕晃，
  /// 裁進水池橢圓後疊在水面上（參考 Cyanilux 2D water 的倒影概念，
  /// 用 Flame 直接複製翻轉 sprite 取代 Unity 的反射攝影機 + RenderTexture）。
  void _renderReflections(Canvas canvas, Offset foot) {
    final sp = position; // 水池中心（世界座標 = boardToScreen(location)）
    // 後方(螢幕較上)相鄰格上的塔。
    final towerCells = <BoardPoint>[
      for (final n in location.getNeighbors())
        if (game.towers[n] != null && game.boardToScreen(n).y < sp.y) n,
    ];
    // 靠近且在後方、還活著的敵人（型別由 game.enemies 推得為 EnemyComponent）。
    final range = size.x * 1.1;
    final enemies = [
      for (final e in game.enemies)
        if (!e.isDead &&
            e.position.y < sp.y &&
            (e.position - sp).length2 < range * range)
          e,
    ];
    if (towerCells.isEmpty && enemies.isEmpty) return;

    // 藍色調 + 淡出一次套在整個倒影圖層上（srcATop 只染有內容處，空白處維持透明）。
    canvas
      ..save()
      ..clipPath(_groundPath(foot, wobble: _pondWobble))
      ..saveLayer(
        null,
        Paint()
          ..color = Colors.white.withOpacity(_reflAlpha)
          ..colorFilter = const ColorFilter.mode(_reflTint, BlendMode.srcATop),
      );

    // 塔：sprite 圍繞元件中心；翻轉後往水池中心拉近(_reflPull)，讓倒影落在水面內。
    for (final n in towerCells) {
      final t = game.towers[n]!;
      final sc = game.boardToScreen(n);
      final lc = Offset(sc.x - sp.x + foot.dx, sc.y - sp.y + foot.dy);
      final sz = t.size;
      final sway = sin(_t * 1.3 + n.q * 1.7 + n.r * 0.9) * _reflSway;
      final pull = (foot - lc) * _reflPull;
      canvas
        ..save()
        ..translate(pull.dx + sway, pull.dy)
        ..translate(0, lc.dy)
        ..scale(1, -_reflScaleY)
        ..translate(0, -lc.dy);
      t.sprite.render(
        canvas,
        position: Vector2(lc.dx - sz.x / 2, lc.dy - sz.y / 2),
        size: sz,
      );
      canvas.restore();
    }

    // 敵人：renderBody 圍繞 local 原點(=接地點)繪製；把原點移到牠在水池內的
    // 位置(往中心拉 _reflPull)後直接垂直翻轉（會隨牠移動每幀更新）。
    for (final e in enemies) {
      final lc =
          Offset(e.position.x - sp.x + foot.dx, e.position.y - sp.y + foot.dy);
      final sway = sin(_t * 1.3 + (e.hashCode % 100) * 0.1) * _reflSway;
      final o = lc + (foot - lc) * _reflPull; // 往水池中心拉近的接地點
      canvas
        ..save()
        ..translate(o.dx + sway, o.dy)
        ..scale(1, -_reflScaleY);
      e.renderBody(canvas);
      canvas.restore();
    }

    canvas
      ..restore() // saveLayer
      ..restore(); // clipPath
  }

  /// 用貼地橢圓填一塊顏色。
  void _flat(Canvas canvas, Offset foot, Color col, {double wobble = 0}) =>
      canvas.drawPath(_groundPath(foot, wobble: wobble), Paint()..color = col);
}

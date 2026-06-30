import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../board/hex.dart';
import '../../tower_defense_game.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';

/// 陷阱基底：蓋在地面、**不阻擋敵人**（不進 `towers` Map，尋路看不到），
/// 可蓋在敵人路徑上。敵人位於同格範圍內時，每隔 [fireCD] 觸發一次。
///
/// 畫在較低 priority（敵人/塔之下、棋盤之上），呈現「貼地」效果。
class TrapComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  TrapComponent(this.type, this.location);

  final TowerType type;
  final BoardPoint location;

  /// top-down 邏輯位置（範圍判定用）。
  final Vector2 logicalPos = Vector2.zero();

  double _cd = 0;

  TowerStats get stats => statsOf(type);
  double get range => stats.range;
  double get damage => stats.damage;
  int get fireCD => stats.fireCD;

  @override
  void onMount() {
    super.onMount();
    logicalPos.setFrom(game.boardToLogical(location));
    anchor = Anchor.center;
    position.setFrom(game.boardToScreen(location));
    priority = -1; // 貼地：棋盤(-2)之上、敵人/塔(螢幕 y>0)之下
  }

  @override
  void update(double dt) {
    _cd = (_cd - dt * 1000).clamp(0, fireCD.toDouble());
    if (_cd > 0) return;
    final hit = game.enemiesInRange(logicalPos, range).toList();
    if (hit.isEmpty) return;
    for (final e in hit) {
      onTrigger(e);
    }
    _cd = fireCD.toDouble();
  }

  /// 觸發效果（子類覆寫）。
  void onTrigger(EnemyComponent enemy) {}
}

/// 依陷阱種建立對應的元件（目前僅尖刺）。
TrapComponent buildTrap(TowerType type, BoardPoint location) {
  switch (type) {
    case TowerType.spike:
      return SpikeTrapComponent(location);
    default:
      return SpikeTrapComponent(location);
  }
}

/// 地刺：敵人經過時持續受傷；常駐不消失，命中時短暫發亮回饋。
class SpikeTrapComponent extends TrapComponent {
  SpikeTrapComponent(BoardPoint location) : super(TowerType.spike, location);

  static const double _flashMax = 140;
  double _flash = 0;

  @override
  void onTrigger(EnemyComponent enemy) {
    enemy.dealDamage(damage);
    _flash = _flashMax;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flash > 0) _flash = (_flash - dt * 1000).clamp(0, _flashMax);
  }

  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final r = game.board.hexagonRadius * s;
    final lit = _flash > 0;

    // 貼地基座（iso 扁橢圓陰影）
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.85),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    // 一叢向上的尖刺（螢幕垂直），命中時偏暖色發亮。
    final body = lit ? const Color(0xFFC07A2B) : const Color(0xFF74818D);
    final highlight = lit ? const Color(0xFFFFE7A6) : const Color(0xFFE9EEF3);

    // (相對基座中心的位置, 高度比例)；由後(上)往前(下)畫，前面的蓋住後面的。
    const layout = [
      [-0.42, 0.02, 0.62],
      [0.40, 0.04, 0.62],
      [0.02, -0.10, 0.70],
      [-0.20, 0.18, 0.92],
      [0.24, 0.18, 0.92],
    ];
    for (final spike in layout) {
      final cx = spike[0] * r;
      final cy = spike[1] * r;
      final h = spike[2] * r;
      final w = r * 0.17;
      // 主體三角
      canvas.drawPath(
        Path()
          ..moveTo(cx - w, cy)
          ..lineTo(cx, cy - h)
          ..lineTo(cx + w, cy)
          ..close(),
        Paint()..color = body,
      );
      // 左半高光，增加立體感
      canvas.drawPath(
        Path()
          ..moveTo(cx - w, cy)
          ..lineTo(cx, cy - h)
          ..lineTo(cx, cy)
          ..close(),
        Paint()..color = highlight.withOpacity(0.9),
      );
    }
  }
}

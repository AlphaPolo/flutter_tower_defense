import 'dart:math';

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

  /// 對敵人的「路線位置 [pos]」施加位置力場（就地修改），預設無作用。
  /// 渦流陷阱覆寫此方法把敵人往中心拉。[seed]＝敵人身分（穩定散布角度用）。
  void pullPosition(Vector2 pos, int seed) {}

  /// 在路線位置 [pos] 處對敵人路線進度的減速係數（1＝不減速），預設不減速。
  double slowFactor(Vector2 pos) => 1.0;
}

/// 依陷阱種建立對應的元件（目前僅尖刺）。
TrapComponent buildTrap(TowerType type, BoardPoint location) {
  switch (type) {
    case TowerType.vortex:
      return VortexTrapComponent(location);
    case TowerType.spike:
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

    // KayKit 地牢尖刺：去掉平板金屬地面與外框，只留原素材的圓孔內壁 + 尖刺。
    // 無陰影；垂直位移讓圓孔座落在格中心（貼地），尖刺往上。
    // 命中時以暖色 srcATop 疊染做「觸發發亮」回饋。
    final w = r * 1.4;
    game.spikeTrapSprite.render(
      canvas,
      position: Vector2(-w / 2, -0.52 * w),
      size: Vector2(w, w),
      overridePaint: lit
          ? (Paint()
            ..colorFilter = const ColorFilter.mode(
                Color(0x88FF8A3D), BlendMode.srcATop))
          : null,
    );
  }
}

/// 渦流陷阱：每隔一段時間進入一次「持續吸引」（含淡入淡出），把 [range] 內的敵人
/// 吸聚到中心附近形成鬆散的一團（方便範圍攻擊），但不造成傷害、不擋路、不鎖死。
///
/// 實作為「空間力場」：敵人每幀算完路線位置後，呼叫 [pullPosition] 依「與中心的
/// 距離」就地把顯示位置往中心拉 —— 純空間計算、不在敵人身上存任何額外狀態
/// （只用一個 logicalPos）。因為力場大小由路線距離決定、到邊緣為 0，敵人不會被
/// 鎖死，離開範圍時也會平滑復原，且完全不影響尋路進度。
class VortexTrapComponent extends TrapComponent {
  VortexTrapComponent(BoardPoint location) : super(TowerType.vortex, location);

  /// 中心處的最大吸引比例（往中心拉多少）；邊緣為 0，平滑過渡。
  static const double _strength = 0.85;

  /// 聚集環半徑（格）：依敵人身分散布在中心周圍的小環上，避免完全重疊。
  static const double _clumpHex = 0.45;

  /// 中心處最多放慢多少路線進度（0.8＝中心只剩 20% 速；邊緣不減速）。
  static const double _slowAmount = 0.8;

  // ── 吸引週期：閒置 _idleMs → 持續吸引 _activeMs，循環；切換時用 _rampMs 淡入淡出 ──
  static const double _idleMs = 4000; // 兩次吸引之間的間隔（稍長）
  static const double _activeMs = 1600; // 每次持續吸引的時間
  static const double _rampMs = 500; // 開始/結束時強度淡入淡出，避免瞬間鬆開跳動

  double _spin = 0; // 視覺旋轉
  double _phaseT = 0; // 當前階段計時
  bool _active = false; // 是否在吸引階段
  double _intensity = 0; // 0~1：實際吸引強度（含淡入淡出）

  @override
  void update(double dt) {
    final dtMs = dt * 1000;

    // 階段機：閒置 ↔ 吸引
    _phaseT += dtMs;
    if (_active) {
      if (_phaseT >= _activeMs) {
        _active = false;
        _phaseT = 0;
      }
    } else if (_phaseT >= _idleMs) {
      _active = true;
      _phaseT = 0;
    }

    // 強度往目標(_active?1:0)線性淡入/淡出 → 吸引開始/結束都平滑
    final target = _active ? 1.0 : 0.0;
    final step = dtMs / _rampMs;
    _intensity = target > _intensity
        ? min(target, _intensity + step)
        : max(target, _intensity - step);

    _spin += dt * (1.0 + 2.5 * _intensity); // 吸引時轉得更快
  }

  /// 空間力場：依「路線位置 [pos] 到中心的距離」把 [pos] 往中心附近的環上拉，
  /// 並乘上目前吸引強度 [_intensity]（淡入淡出）。邊緣為 0 → 不鎖死、離開即復原。
  @override
  void pullPosition(Vector2 pos, int seed) {
    if (_intensity <= 0) return;
    final r = game.board.hexagonRadius * range;
    final d = pos.distanceTo(logicalPos);
    if (d >= r) return;
    final k = (1 - d / r) * _strength * _intensity;
    final a = (seed % 628) / 100.0; // 穩定角度 → 環狀散開、不完全重疊
    final clump = game.board.hexagonRadius * _clumpHex;
    pos.x += (logicalPos.x + cos(a) * clump - pos.x) * k;
    pos.y += (logicalPos.y + sin(a) * clump - pos.y) * k;
  }

  /// 吸引時真的放慢路線進度（與力場同步淡入淡出）：中心最慢、邊緣不減速。
  @override
  double slowFactor(Vector2 pos) {
    if (_intensity <= 0) return 1.0;
    final r = game.board.hexagonRadius * range;
    final d = pos.distanceTo(logicalPos);
    if (d >= r) return 1.0;
    return 1 - (1 - d / r) * _slowAmount * _intensity;
  }

  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final r = game.board.hexagonRadius * s;
    const color = Color(0xFF9C6BFF);
    final glow = 0.35 + 0.65 * _intensity; // 吸引時更亮、閒置時黯淡待命

    // 貼地凹陷（吸引時更深）
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 0.95),
      Paint()..color = Colors.black.withValues(alpha: 0.14 + 0.18 * _intensity),
    );

    // 旋臂（螺旋弧，y 壓扁成貼地）
    const arms = 3;
    for (var k = 0; k < arms; k++) {
      final base = _spin + k * 2 * pi / arms;
      final path = Path();
      for (var i = 0; i <= 20; i++) {
        final tt = i / 20;
        final rad = r * 0.78 * tt;
        final ang = base + tt * 2.2;
        final x = cos(ang) * rad;
        final y = sin(ang) * rad * 0.55;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.2 + 0.8 * _intensity) * s
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: glow),
      );
    }

    // 中心核心
    canvas.drawCircle(
      Offset.zero,
      (3 + 1.8 * _intensity) * s,
      Paint()..color = color.withValues(alpha: 0.6 + 0.4 * _intensity),
    );
  }
}

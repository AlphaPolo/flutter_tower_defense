import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../board/hex.dart';
import '../effects/effect.dart';
import '../effects/particles.dart';
import '../tower_defense_game.dart';
import 'enemy_status.dart';

export 'enemy_status.dart';

/// 沿 flow-field 前進的敵人。
///
/// 移動與受傷都在 top-down「邏輯座標」([logicalPos]) 計算；每幀再投影成
/// isometric 螢幕座標設給 Flame 的 [position] 來繪製，並依螢幕 y 設定 priority
/// 做深度排序。
class EnemyComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  EnemyComponent({
    required this.currentLocation,
    required this.status,
  }) : super(anchor: Anchor.center);

  static const double speedComplete = 16 * 60;

  BoardPoint currentLocation;
  BoardPoint? goalLocation;
  EnemyStatus status;
  EnemyStatus? afterEffects;

  final List<BaseEffect> effects = [];

  /// top-down 邏輯位置（瞄準/射程/繪製都用這個）。
  final Vector2 logicalPos = Vector2.zero();

  bool _dead = false;
  bool _settled = false;

  double _progress = 0;
  final Vector2 _segFrom = Vector2.zero();
  final Vector2 _segTo = Vector2.zero();

  bool get isDead => _dead;

  @override
  void onMount() {
    super.onMount();
    game.registerEnemy(this);
    logicalPos.setFrom(game.boardToLogical(currentLocation));
    _syncScreen();
  }

  @override
  void onRemove() {
    game.unregisterEnemy(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (isDead) return;

    final dtMs = dt * 1000;
    afterEffects = _tickEffects(dtMs.round());
    var speed = (afterEffects ?? status).speed;

    if (goalLocation == null) {
      final dir = game.guide[currentLocation];
      if (dir == null) return;
      goalLocation = currentLocation.getNeighbor(dir);
      _segFrom.setFrom(game.boardToLogical(currentLocation));
      _segTo.setFrom(game.boardToLogical(goalLocation!));
      _progress = 0;
    }

    // 目前在路線上的位置（由現有狀態算出，不存欄位）。被渦流吸引時，依此位置
    // 真的放慢路線進度 → 進度不會偷跑、出渦流不暴衝（最低不為 0，故不會被鎖死）。
    final t0 = (_progress / speedComplete).clamp(0.0, 1.0);
    final here = _segFrom + (_segTo - _segFrom) * t0;
    speed *= game.trapSlowFactor(here);

    _progress += dtMs * speed;
    if (_progress >= speedComplete) {
      currentLocation = goalLocation!;
      logicalPos.setFrom(game.boardToLogical(currentLocation));
      goalLocation = null;
      if (currentLocation == game.targetLocation) {
        _reachGoal();
        return;
      }
    } else {
      final t = _progress / speedComplete;
      logicalPos
        ..setFrom(_segTo)
        ..sub(_segFrom)
        ..scale(t)
        ..add(_segFrom);
    }

    // 陷阱位置力場（如渦流）：依與陷阱的距離，就地把顯示位置往中心拉。純空間
    // 計算、不存任何狀態；邊緣為 0 → 不會鎖死、離開即平滑復原，也不影響尋路進度。
    game.applyTrapPull(logicalPos, hashCode);

    _syncScreen();
  }

  void _syncScreen() {
    position.setFrom(game.logicalToScreen(logicalPos));
    priority = position.y.round();
  }

  void dealDamage(double damage) {
    if (isDead) return;
    status = status.sub(hp: damage);
    if (status.currentHp <= 0) _die();
  }

  void _die() {
    if (_settled) return;
    _settled = true;
    _dead = true;
    game.world.add(deathBurst(position.clone(), game.iso.scaleX));
    game.onEnemyKilled(this);
    removeFromParent();
  }

  void _reachGoal() {
    if (_settled) return;
    _settled = true;
    _dead = true;
    game.onEnemyLeaked(this);
    removeFromParent();
  }

  // ── 效果 ─────────────────────────────────────────────────
  EnemyStatus _tickEffects(int dtMs) {
    var dirty = false;
    var result = status;
    var dot = 0.0;
    for (final effect in effects) {
      effect.tick(dtMs);
      result = effect.calc(result);
      dot += effect.takeDamage();
      if (effect.dead) dirty = true;
    }
    if (dot > 0) dealDamage(dot); // 持續傷害（毒等）
    if (dirty) {
      effects.removeWhere((e) {
        if (e.dead) e.onEnd();
        return e.dead;
      });
    }
    return result;
  }

  void addEffect(BaseEffect effect) {
    final index = effects.indexWhere((e) => e.isSameId(effect));
    void packOperation() {
      effect.onAttach();
      effects.add(effect);
      effects.sort();
    }

    if (index < 0) {
      packOperation();
      return;
    }
    switch (effect.idWithType.duplicateStrategy) {
      case EffectDuplicateStrategy.last:
        effects.removeAt(index);
        packOperation();
        break;
      case EffectDuplicateStrategy.none:
        packOperation();
        break;
      case EffectDuplicateStrategy.strongest:
        break;
    }
  }

  // ── 繪製：圓形 + 上方血條（依 isometric 比例縮放）──────────
  @override
  void render(Canvas canvas) {
    final s = game.iso.scaleX;
    final r = game.board.hexagonRadius * 0.3 * s;
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.indigo);

    final w = r * 2.2;
    final h = r * 0.5;
    final top = -r - h - 2;
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, top, w, h),
      Paint()..color = Colors.grey,
    );
    final ratio = (status.currentHp / status.totalHp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(-w / 2, top, w * ratio, h),
      Paint()..color = Colors.red,
    );
  }
}

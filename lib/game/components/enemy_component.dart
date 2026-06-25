import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../board/hex.dart';
import '../effects/effect.dart';
import '../tower_defense_game.dart';
import 'enemy_status.dart';

export 'enemy_status.dart';

/// 一個會自己沿著 flow-field 前進的敵人。
///
/// 取代舊的 Enemy model + EnemyManager：移動、受傷、死亡、到終點都在這裡用
/// update(dt) 自行處理。
class EnemyComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  EnemyComponent({
    required this.currentLocation,
    required this.status,
  }) : super(priority: 20, anchor: Anchor.center);

  /// 假設怪物速度是 1，走完一格要 16ms * 60 = 60 幀。
  static const double speedComplete = 16 * 60;

  BoardPoint currentLocation;
  BoardPoint? goalLocation;
  EnemyStatus status;
  EnemyStatus? afterEffects;

  final List<BaseEffect> effects = [];

  bool _dead = false;
  bool _settled = false;

  double _progress = 0;
  Vector2 _segFrom = Vector2.zero();
  Vector2 _segTo = Vector2.zero();

  bool get isDead => _dead;

  @override
  void onMount() {
    super.onMount();
    game.registerEnemy(this);
    position = game.boardToWorld(currentLocation);
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
    final speed = (afterEffects ?? status).speed;

    if (goalLocation == null) {
      final dir = game.guide[currentLocation];
      if (dir == null) return; // 暫時沒有路可走
      goalLocation = currentLocation.getNeighbor(dir);
      _segFrom = game.boardToWorld(currentLocation);
      _segTo = game.boardToWorld(goalLocation!);
      _progress = 0;
    }

    _progress += dtMs * speed;
    if (_progress >= speedComplete) {
      currentLocation = goalLocation!;
      position = game.boardToWorld(currentLocation);
      goalLocation = null;
      if (currentLocation == game.targetLocation) {
        _reachGoal();
      }
    } else {
      final t = _progress / speedComplete;
      position = _segFrom + (_segTo - _segFrom) * t;
    }
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
    for (final effect in effects) {
      effect.tick(dtMs);
      result = effect.calc(result);
      if (effect.dead) dirty = true;
    }
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

  // ── 繪製：靛色圓 + 上方血條 ──────────────────────────────
  @override
  void render(Canvas canvas) {
    final r = game.board.hexagonRadius * 0.3;
    canvas.drawCircle(Offset.zero, r, Paint()..color = Colors.indigo);

    const w = 20.0;
    const h = 5.0;
    final top = -r - h - 1;
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

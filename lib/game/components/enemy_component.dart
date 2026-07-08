import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../board/hex.dart';
import '../effects/effect.dart';
import '../effects/particles.dart';
import '../effects/pop_in.dart';
import '../tower_defense_game.dart';
import 'enemy_kind.dart';
import 'leak_ghost.dart';
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
    required this.kind,
    required this.currentLocation,
    required this.status,
  }) : super(anchor: Anchor.center);

  static const double speedComplete = 16 * 60;

  final EnemyKind kind;
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
  double _animT = 0; // 動畫計時（秒）
  double _healTimer = 0; // 治療型：距離下次治療的計時（ms）
  double _healPulse = 0; // 治療瞬間光環閃亮(0..1)，之後衰減
  double _hitFlash = 0; // 命中閃白(0..1)，之後衰減
  double _shake = 0; // 命中震動強度(0..1)，之後衰減（只影響繪製、不動實際位置）
  final Vector2 _segFrom = Vector2.zero();
  final Vector2 _segTo = Vector2.zero();

  bool get isDead => _dead;

  @override
  void onMount() {
    super.onMount();
    game.registerEnemy(this);
    logicalPos.setFrom(game.boardToLogical(currentLocation));
    _syncScreen();
    // 出場 squash & stretch 彈出（與塔共用）。
    scale.setValues(0, 0);
    add(popInEffect());
  }

  @override
  void onRemove() {
    game.unregisterEnemy(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (isDead) return;
    _animT += dt;
    if (_hitFlash > 0) _hitFlash = (_hitFlash - dt / 0.10).clamp(0.0, 1.0);
    if (_shake > 0) _shake = (_shake - dt / 0.18).clamp(0.0, 1.0);

    final dtMs = dt * 1000;
    if (kind.healRange > 0) _tickHeal(dt, dtMs); // 薩滿等治療型
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
    speed *= game.envSlowAt(currentLocation); // 泥沼等天然環境減速

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

    // 荊棘等天然環境：站在上面持續受少量傷害。
    final envDps = game.envDpsAt(currentLocation);
    if (envDps > 0) {
      dealDamage(envDps * dt, physical: false, feedback: false);
      if (isDead) return;
    }

    _syncScreen();
  }

  void _syncScreen() {
    position.setFrom(game.logicalToScreen(logicalPos));
    priority = position.y.round();
  }

  /// 對敵人造成傷害。[physical]=true（滾木/火炮/風刃/地刺等直擊）會被「脆弱化」
  /// (VulnerableEffect) 放大；元素/持續傷害（火焰、毒、雷電）傳 false，不受放大。
  void dealDamage(double damage, {bool physical = true, bool feedback = true}) {
    if (isDead) return;
    // 命中回饋：閃白 + 震動（連續傷害如毒/火/荊棘傳 feedback:false，避免持續閃爍）。
    if (feedback) {
      _hitFlash = 1;
      _shake = 1;
    }
    var dmg = damage;
    if (physical) {
      var amp = 0.0;
      for (final e in effects) {
        if (e is VulnerableEffect && e.physicalAmp > amp) amp = e.physicalAmp;
      }
      dmg *= 1 + amp;
    }
    status = status.sub(hp: dmg);
    if (status.currentHp <= 0) _die();
  }

  void _die() {
    if (_settled) return;
    _settled = true;
    _dead = true;
    game.world.add(deathBurst(position.clone(), game.iso.scaleX));
    game.onEnemyKilled(this);
    _spawnSplit(); // 分裂兵：死亡裂出小怪
    removeFromParent();
  }

  /// 分裂兵死亡 → 在同格生出 [EnemyKind.splitCount] 隻小怪。子代血量/速度由「還原
  /// 本波基準 × 子種倍率」推得；速度略作差異讓牠們散開、不會完全重疊。
  void _spawnSplit() {
    final child = kind.splitInto;
    if (child == null || kind.splitCount <= 0) return;
    final baseHp = status.totalHp / kind.hpMul;
    final baseSpeed = status.speed / kind.speedMul;
    for (var i = 0; i < kind.splitCount; i++) {
      final hp = baseHp * child.hpMul;
      final spread = 0.85 + 0.15 * i; // 0.85 / 1.0 / 1.15… → 沿路拉開距離
      game.spawnEnemy(EnemyComponent(
        kind: child,
        currentLocation: currentLocation,
        status: EnemyStatus(
          totalHp: hp,
          currentHp: hp,
          speed: baseSpeed * child.speedMul * spread,
        ),
      ));
    }
  }

  void _reachGoal() {
    if (_settled) return;
    _settled = true;
    _dead = true;
    game.onEnemyLeaked(this);
    // 抵達主堡後留下一個純視覺替身淡出（不進 game.enemies → 塔不會鎖定/命中）。
    game.world.add(LeakGhostComponent(
      kind: kind,
      screenPos: position.clone(),
      faceLeft: _faceLeft(),
      animT: _animT,
    ));
    removeFromParent();
  }

  /// 依螢幕水平移動方向判斷是否朝左（素材預設朝右）。
  bool _faceLeft() =>
      game.logicalToScreen(_segTo).x - game.logicalToScreen(_segFrom).x < 0;

  // ── 治療（薩滿等支援型）─────────────────────────────────────
  void _tickHeal(double dt, double dtMs) {
    _healPulse = (_healPulse - dt * 2).clamp(0.0, 1.0);
    _healTimer += dtMs;
    if (_healTimer >= kind.healIntervalMs) {
      _healTimer = 0;
      if (_healNearby()) _healPulse = 1.0; // 有奶到人才閃光環
    }
  }

  /// 治療範圍內「其他」未滿血的敵人：每隻回復其最大血量 × [EnemyKind.healFrac]。
  /// 回傳是否至少治療到一隻。
  bool _healNearby() {
    final range = game.board.hexagonRadius * kind.healRange;
    var any = false;
    for (final e in game.enemies) {
      if (identical(e, this) || e.isDead) continue;
      final st = e.status;
      if (st.currentHp >= st.totalHp) continue;
      if (logicalPos.distanceTo(e.logicalPos) > range) continue;
      final hp = (st.currentHp + st.totalHp * kind.healFrac)
          .clamp(0.0, st.totalHp)
          .toDouble();
      e.status = st.copyWith(currentHp: hp);
      any = true;
    }
    return any;
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
    if (dot > 0) {
      dealDamage(dot, physical: false, feedback: false); // 持續傷害(毒/火)：非物理、不閃白
    }
    if (dirty) {
      effects.removeWhere((e) {
        if (e.dead) e.onEnd();
        return e.dead;
      });
    }
    return result;
  }

  /// 疊一層流血：已有同型流血就疊層+續期，否則新增一個。
  void addBleed(IdWithEffectType id, double perStackDps,
      {int maxStacks = 8, int durationMs = 2500}) {
    for (final ef in effects) {
      if (ef is BleedEffect && ef.idWithType.sameTypeId == id.sameTypeId) {
        ef.refresh(durationMs);
        return;
      }
    }
    addEffect(BleedEffect(id, durationMs, perStackDps, maxStacks));
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

  // ── 繪製：身體(billboard/色圓) + 上方血條（依 isometric 比例縮放）──────
  @override
  void render(Canvas canvas) {
    if (kind.healRange > 0) _renderHealAura(canvas); // 治療型腳下光環
    final sh = _shakeOffset();
    if (sh == Offset.zero) {
      renderBody(canvas);
    } else {
      canvas
        ..save()
        ..translate(sh.dx, sh.dy);
      renderBody(canvas);
      canvas.restore();
    }
    _renderHealthBar(canvas);
  }

  /// 命中震動位移（原理同相機震動：暫時偏移、隨強度衰減回 0）。只影響繪製，
  /// 不動 [logicalPos]/[position]，所以不影響實際位置與尋路。
  Offset _shakeOffset() {
    if (_shake <= 0) return Offset.zero;
    final s = game.iso.scaleX;
    final k = _shake * _shake; // 平方 → 收尾更快、更像撞擊
    return Offset(
      sin(_animT * 90) * 3.5 * s * k,
      cos(_animT * 75) * 2.2 * s * k,
    );
  }

  /// 治療型敵人腳下的綠色貼地光環（顯示治療範圍，治療瞬間變亮）。
  void _renderHealAura(Canvas canvas) {
    final s = game.iso.scaleX;
    final r = game.board.hexagonRadius * kind.healRange * s;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.5 + 2 * _healPulse) * s
        ..color = const Color(0xFF3DE08A).withOpacity(0.20 + 0.5 * _healPulse),
    );
  }

  /// 只畫敵人「身體」(直立 billboard 或退回色圓)，圍繞 local 原點(＝接地點)
  /// 繪製、不含血條。水池倒影會重用它（翻轉＋染色後再畫一次）。
  void renderBody(Canvas canvas) {
    final s = game.iso.scaleX;
    final img = game.enemySheets[kind.id];
    if (img != null) {
      // 直立 billboard：底邊貼地(0,0)、往上豎起；素材自帶陰影落在地面。
      final size = game.board.hexagonRadius * s * 1.9 * kind.sizeMul;
      final frame = (_animT / 0.11).floor() % kind.frames;
      final src = Rect.fromLTWH(
          frame * kind.frameSize, 0, kind.frameSize, kind.frameSize);
      // 依各自「腳底」對齊同一條地面線：讓內容底部落在格子中心下方 0.12size，
      // 這樣不同角色高矮不一也都站在同一水平（修正 Boss 偏低等問題）。
      final centerY = size * (0.62 - kind.footFrac);
      final dst =
          Rect.fromCenter(center: Offset(0, centerY), width: size, height: size);
      // 依螢幕水平移動方向翻轉（素材預設朝右）。
      final faceLeft = _faceLeft();
      final fq = kind.pixel ? FilterQuality.none : FilterQuality.medium;
      canvas.save();
      if (faceLeft) canvas.scale(-1, 1);
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = fq);
      if (_hitFlash > 0) {
        // 命中閃白：以 srcATop 在不透明像素上疊白，alpha＝閃白強度。
        canvas.drawImageRect(
          img,
          src,
          dst,
          Paint()
            ..filterQuality = fq
            ..colorFilter = ColorFilter.mode(
                Colors.white.withOpacity(_hitFlash), BlendMode.srcATop),
        );
      }
      canvas.restore();
    } else {
      final r = game.board.hexagonRadius * 0.3 * kind.sizeMul * s;
      canvas.drawCircle(Offset.zero, r, Paint()..color = kind.color);
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * s
          ..color = Colors.black.withOpacity(0.35),
      );
      if (_hitFlash > 0) {
        canvas.drawCircle(
            Offset.zero, r, Paint()..color = Colors.white.withOpacity(_hitFlash * 0.9));
      }
    }
  }

  /// 頭頂上方的血條（依 billboard／色圓分別推算位置）。
  void _renderHealthBar(Canvas canvas) {
    final s = game.iso.scaleX;
    final img = game.enemySheets[kind.id];
    double barTop;
    double barW;
    if (img != null) {
      final size = game.board.hexagonRadius * s * 1.9 * kind.sizeMul;
      // 血條在頭頂上方（依 topFrac 推算頭部位置）。
      final headY = size * (0.12 - kind.footFrac + kind.topFrac);
      barTop = headY - size * 0.05;
      barW = size * 0.4;
    } else {
      final r = game.board.hexagonRadius * 0.3 * kind.sizeMul * s;
      barW = r * 2.2;
      barTop = -r - r * 0.5 - 2;
    }
    final barH = game.board.hexagonRadius * 0.14 * s;
    canvas.drawRect(
      Rect.fromLTWH(-barW / 2, barTop, barW, barH),
      Paint()..color = Colors.grey,
    );
    final ratio = (status.currentHp / status.totalHp).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(-barW / 2, barTop, barW * ratio, barH),
      Paint()..color = Colors.red,
    );
  }
}

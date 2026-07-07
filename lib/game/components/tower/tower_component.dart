import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../audio/game_audio.dart';
import '../../board/hex.dart';
import '../../effects/pop_in.dart';
import '../../tower_defense_game.dart';
import '../../tower_type.dart';
import '../enemy_component.dart';
import '../projectile/projectile.dart';

/// 防禦塔基底（isometric 版）。瞄準/射程在 top-down 邏輯座標計算；繪製用
/// 預先渲染好的 isometric 塔素材，放在格子的螢幕座標上，依螢幕 y 排序深度。
class TowerComponent extends PositionComponent
    with HasGameReference<TowerDefenseGame> {
  TowerComponent(this.type, this.location);

  final TowerType type;
  final BoardPoint location;

  /// 已選的升級節點（依序 [Lv2 分支, Lv3 葉]）與已投入的升級花費（拆除退款用）。
  final List<TowerUpgradeNode> chosen = [];
  int spentOnUpgrades = 0;

  /// 目前等級（1 起）＝ 基礎 + 已選節點數。
  int get level => 1 + chosen.length;

  /// 已選節點疊出來的「有效數值覆寫」（葉覆寫分支覆寫基礎）。
  final Map<TowerMod, double> _mods = {};

  /// 讀有效數值：有升級覆寫就用覆寫，否則用 [base]。
  double mod(TowerMod key, double base) => _mods[key] ?? base;

  /// 套用一個升級節點（加入 chosen 並疊上其 mods）。
  void applyUpgrade(TowerUpgradeNode node) {
    chosen.add(node);
    _mods.addAll(node.mods);
  }

  double direction = 0;
  EnemyComponent? target;
  double prepareShoot = 0;

  /// 相鄰是否有多重箭支援塔的「快取」——只在建造/拆除時由 game 重算，
  /// 各塔每幀只讀這個 bool（不用每幀掃鄰格、零配置）。
  bool multishotBuffed = false;

  /// top-down 邏輯位置。
  final Vector2 logicalPos = Vector2.zero();

  TowerStats get stats => statsOf(type);
  int get cost => stats.cost;
  double get range => stats.range;
  double get damage => stats.damage;
  int get fireCD => stats.fireCD;

  Sprite get sprite => game.towerSprites[type]!;

  /// 障礙物用較大的縮放（石頭原始很小）。
  double get spriteScale => 1.0;

  @override
  void onMount() {
    super.onMount();
    logicalPos.setFrom(game.boardToLogical(location));
    anchor = Anchor.center;
    size = sprite.srcSize * spriteScale;
    position.setFrom(game.boardToScreen(location));
    priority = position.y.round();

    // 蓋出來時的 squash & stretch 彈出（塔與敵人共用 popInEffect）。
    scale.setValues(0, 0);
    add(popInEffect());
  }

  @override
  void update(double dt) {
    prepareShoot = (prepareShoot - dt * 1000).clamp(0, fireCD.toDouble());
    if (prepareShoot > 0) return;

    target ??= game.nearestEnemy(logicalPos, range);
    final t = target;
    if (t == null) return;

    if (t.isDead || !t.isMounted) {
      target = null;
      return;
    }
    final diff = t.logicalPos - logicalPos;
    if (!game.isInsideRange(diff, range)) {
      target = null;
      return;
    }
    direction = atan2(diff.y, diff.x);
    attemptShoot(t);
  }

  void attemptShoot(EnemyComponent enemy) {
    if (prepareShoot > 0) return;
    final projectile = createProjectile(enemy);
    if (projectile != null) {
      game.world.add(projectile);
      GameAudio.fire(type, position); // 3D 定位開火音（依塔種）
    }
    prepareShoot = fireCD.toDouble();
  }

  /// 對射程內最近的 [n] 個敵人各發射一次（多重箭增益用）。有開火回 true。
  /// 每發前先把 direction 對準該敵人（muzzle 依 direction）。
  bool shootNearest(int n) {
    final targets = game.enemiesInRange(logicalPos, range)
        .sortedBy<num>((e) => logicalPos.distanceToSquared(e.logicalPos));
    if (targets.isEmpty) return false;
    var fired = false;
    for (final e in targets.take(n)) {
      final diff = e.logicalPos - logicalPos;
      direction = atan2(diff.y, diff.x);
      final p = createProjectile(e);
      if (p != null) {
        game.world.add(p);
        fired = true;
      }
    }
    if (fired) GameAudio.fire(type, position);
    return true;
  }

  ProjectileComponent? createProjectile(EnemyComponent enemy) {
    return NormalProjectileComponent(
      damage: damage,
      start: muzzle(),
      speed: 1,
      target: enemy,
    );
  }

  /// 砲口（邏輯座標）。
  Vector2 muzzle([double dist = 32]) =>
      logicalPos + Vector2(cos(direction), sin(direction)) * dist;

  @override
  void render(Canvas canvas) {
    if (type != TowerType.obstacle) _renderShadow(canvas); // 障礙物(石頭)不畫陰影
    sprite.render(canvas, size: size);
    _renderLevelPips(canvas);
  }

  /// 可升級的塔在腳邊畫等級小圓點（已達等級亮黃、其餘灰）。
  void _renderLevelPips(Canvas canvas) {
    final maxLv = maxLevelOf(type);
    if (maxLv <= 1) return;
    final s = game.iso.scaleX;
    final r = 2.6 * s;
    final gap = r * 2.6;
    final cx = size.x / 2;
    final cy = size.y / 2 + game.board.hexagonRadius * 0.42 * s; // 腳邊下方
    final startX = cx - gap * (maxLv - 1) / 2;
    for (var i = 0; i < maxLv; i++) {
      canvas.drawCircle(
        Offset(startX + gap * i, cy),
        r,
        Paint()
          ..color = i < level ? Colors.amber : Colors.black.withOpacity(0.35),
      );
    }
  }

  // 貼地陰影用的共用 paint（已烘好模糊、不再每幀 MaskFilter）；low 讓縮放平順。
  static final Paint _shadowPaint = Paint()..filterQuality = FilterQuality.low;

  /// 在塔腳底貼一張「起動時烘好的模糊陰影圖」（game.towerShadowImage）。
  /// 影像已含高斯柔邊與 iso 貼地角度，故這裡只做一次便宜的 drawImageRect，
  /// 免掉每幀每塔的 MaskFilter.blur（saveLayer + 高斯）成本。
  void _renderShadow(Canvas canvas) {
    final img = game.towerShadowImage;
    final anchor = game.towerShadowAnchor; // 影像內的塔腳像素座標
    final foot = Offset(size.x / 2, size.y / 2); // 塔腳＝sprite 中心
    final w = img.width.toDouble(), h = img.height.toDouble();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, w, h),
      Rect.fromLTWH(foot.dx - anchor.dx, foot.dy - anchor.dy, w, h),
      _shadowPaint,
    );
  }
}

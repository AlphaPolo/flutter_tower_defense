import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../board/hex.dart';
import '../tower_defense_game.dart';

/// 每場隨機佈置的天然環境種類。
/// [blocks]＝是否阻擋敵人路線（也一律不可在上面建塔，見 game.isPlaceable）。
enum EnvType {
  boulder(blocks: true, label: '巨石', desc: '天然巨石，單純阻擋敵人前進。'),
  pond(blocks: true, label: '水池', desc: '無法跨越的水池，阻擋路線。'),
  woods(blocks: true, label: '密林', desc: '茂密樹林，阻擋路線。風刃塔蓋在旁邊時，每波會產出金幣（每片密林各算一次）。'),
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
  double _t = 0; // 水面 shader 的動畫時間

  // ── 水面倒影可調參數（Route B）──────────────────────────────
  static const double _reflScaleY = 0.9; // 垂直壓縮（水面透視感）
  static const double _reflAmt = 0.7; // 倒影不透明度（傳進 shader，按 R 生效）
  static const double _reflRefract = 0.016; // 倒影左右搖擺幅度（按 R 生效）
  // 倒影往水池中心拉近的比例：0＝落在物件腳下(常被裁掉、露出少)，1＝拉到池中央。
  static const double _reflPull = 0.3;

  ui.Image? _reflImg; // 本幀倒影圖（延後一幀釋放，避免 GPU 記憶體累積）
  static ui.Image? _blankImg; // 沒有可倒映物件時綁的 1x1 透明圖
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
        // KayKit 岩石群 3D 素材（多塊石頭組成），底部對齊格子中心。
        final rw = size.x * 1.2;
        game.rockSprite.render(
          canvas,
          position: Vector2(size.x / 2 - rw / 2, size.y / 2 - rw * 0.5),
          size: Vector2(rw, rw),
        );
        break;
      case EnvType.woods:
        // KayKit 樹叢 3D 素材：畫大一點、樹叢底部對齊格子中心 → 像從格子長出來、
        // 立體地擋在路上（素材裡樹叢底約在圖高 62% 處）。
        final w = size.x * 1.6;
        game.treeSprite.render(
          canvas,
          position: Vector2(size.x / 2 - w / 2, size.y / 2 - w * 0.5),
          size: Vector2(w, w),
        );
        break;
      case EnvType.pond:
        final prog = game.waterProgram;
        if (prog != null) {
          // 倒影圖：把後方相鄰的塔/附近敵人翻轉畫進一張圖，交給 shader 逐像素折射。
          // 開關關閉時不建圖（省下每幀 toImageSync），水面照常繪製、只是沒有倒影。
          final refl =
              game.waterReflection.value ? _buildReflectionImage(foot) : null;
          final shader = prog.fragmentShader()
            ..setFloat(0, size.x)
            ..setFloat(1, size.y)
            ..setFloat(2, _t)
            ..setFloat(3, refl != null ? _reflAmt : 0.0)
            ..setFloat(4, _reflRefract)
            ..setImageSampler(0, refl ?? _blank());
          canvas
            ..save()
            ..clipPath(_groundPath(foot, wobble: _pondWobble))
            ..drawRect(
                Offset.zero & Size(size.x, size.y), Paint()..shader = shader)
            ..restore();
          _reflImg?.dispose(); // 釋放上一幀（已光柵化）的圖
          _reflImg = refl;
        } else {
          // 退回：平面水池 + 反光（無 shader → 無倒影）。
          _flat(canvas, foot, const Color(0xCC1E88E5), wobble: _pondWobble);
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
        // KayKit 灌木叢 3D 素材（帶刺矮樹叢），底部對齊格子中心。
        final tw = size.x * 1.3;
        game.thornsSprite.render(
          canvas,
          position: Vector2(size.x / 2 - tw / 2, size.y / 2 - tw * 0.5),
          size: Vector2(tw, tw),
        );
        break;
    }
  }

  Path? _cachedGround; // 剪裁路徑對本元件固定 → 只算一次、之後每幀重用
  double? _cachedWobble;

  /// 貼地的路徑（用 iso 地面基向量，讓它躺在地面角度上）。
  /// [wobble]>0 時把半徑依角度做週期擾動 → 有機、非正圓的外型；用 location 當
  /// 種子，讓每個水池長得不一樣但每幀穩定（不會抖）。
  /// foot／iso／半徑／wobble 對本元件皆固定，故算一次後快取重用（免每幀重建）。
  Path _groundPath(Offset foot, {double wobble = 0}) {
    final cached = _cachedGround;
    if (cached != null && _cachedWobble == wobble) return cached;
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
    _cachedWobble = wobble;
    return _cachedGround = (path..close());
  }

  /// 建立本幀的「倒影圖」：把水池後方相鄰的塔與附近敵人翻轉、往池中心拉近、
  /// 垂直壓縮後畫進一張與水池同尺寸的圖（不染色、不折射 → 交給 water.frag 逐像素
  /// 折射與上色）。沒有可倒映物件時回傳 null（呼叫端改綁透明圖、關閉倒影）。
  ui.Image? _buildReflectionImage(Offset foot) {
    final sp = position; // 水池中心（世界座標 = boardToScreen(location)）
    final towerCells = <BoardPoint>[
      for (final n in location.getNeighbors())
        if (game.towers[n] != null && game.boardToScreen(n).y < sp.y) n,
    ];
    final range = size.x * 1.1;
    final enemies = [
      for (final e in game.enemies)
        if (!e.isDead &&
            e.position.y < sp.y &&
            (e.position - sp).length2 < range * range)
          e,
    ];
    if (towerCells.isEmpty && enemies.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final rc = Canvas(recorder);
    // 塔：以接地點(格中心)鏡射、往池中心拉近、垂直壓縮。
    for (final n in towerCells) {
      final t = game.towers[n]!;
      final sc = game.boardToScreen(n);
      final lc = Offset(sc.x - sp.x + foot.dx, sc.y - sp.y + foot.dy);
      final sz = t.size;
      final pull = (foot - lc) * _reflPull;
      rc
        ..save()
        ..translate(pull.dx, pull.dy)
        ..translate(0, lc.dy)
        ..scale(1, -_reflScaleY)
        ..translate(0, -lc.dy);
      t.sprite.render(rc,
          position: Vector2(lc.dx - sz.x / 2, lc.dy - sz.y / 2), size: sz);
      rc.restore();
    }
    // 敵人：renderBody 圍繞原點(接地點)繪製，把原點移到水池內位置後翻轉。
    for (final e in enemies) {
      final lc =
          Offset(e.position.x - sp.x + foot.dx, e.position.y - sp.y + foot.dy);
      final o = lc + (foot - lc) * _reflPull;
      rc
        ..save()
        ..translate(o.dx, o.dy)
        ..scale(1, -_reflScaleY);
      e.renderBody(rc);
      rc.restore();
    }
    final picture = recorder.endRecording();
    final img = picture.toImageSync(
        size.x.ceil().clamp(1, 2048), size.y.ceil().clamp(1, 2048));
    picture.dispose();
    return img;
  }

  /// sampler 一定要綁東西：沒有倒影時綁這張快取的 1x1 透明圖。
  ui.Image _blank() {
    final cached = _blankImg;
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    Canvas(recorder); // 什麼都不畫 → 透明
    return _blankImg = recorder.endRecording().toImageSync(1, 1);
  }

  @override
  void onRemove() {
    _reflImg?.dispose();
    _reflImg = null;
    super.onRemove();
  }

  /// 用貼地橢圓填一塊顏色。
  void _flat(Canvas canvas, Offset foot, Color col, {double wobble = 0}) =>
      canvas.drawPath(_groundPath(foot, wobble: wobble), Paint()..color = col);
}

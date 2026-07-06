import 'package:flutter/material.dart';

/// 一種敵人的設定（不可變）。
///
/// 第一階段只含「屬性 / 外觀 / 經濟 / 波次權重」；抗性與特殊行為（擋滾木、分裂、
/// 補師…）之後的階段再擴充欄位。數值採「相對該波基準」的倍率，spawn 時再乘上
/// `enemyStatusForWave(wave)`。
class EnemyKind {
  const EnemyKind({
    required this.id,
    required this.name,
    required this.hpMul,
    required this.speedMul,
    required this.reward,
    required this.leakDamage,
    required this.color,
    required this.sizeMul,
    required this.unlockWave,
    required this.weight,
    required this.desc,
    this.sheet,
    this.frames = 1,
    this.frameSize = 0,
    this.footFrac = 0.70,
    this.topFrac = 0.28,
    this.healRange = 0,
    this.healFrac = 0,
    this.healIntervalMs = 1200,
    this.pixel = false,
    this.avatarZoom = 1.0,
    this.avatarDx = 0,
    this.avatarDy = 0,
  });

  final String id;
  final String name; // 顯示名（資訊卡）
  final double hpMul; // 相對該波基準血量倍率
  final double speedMul; // 相對該波基準速度倍率
  final int reward; // 擊殺金幣
  final int leakDamage; // 漏過扣幾點生命
  final Color color; // 顏色圓的顏色
  final double sizeMul; // 圓半徑倍率
  final int unlockWave; // 第幾波開始可能出現
  final double weight; // 權重填充用（越大越常出現）
  final String desc; // 資訊卡說明

  // 動畫 sprite（直立 billboard）。sheet == null 時退回顏色圓。
  final String? sheet; // 水平幀條資產檔名（放 assets/iso/）
  final int frames; // 幀數
  final double frameSize; // 每幀像素（正方形）
  final double footFrac; // 內容「底部(腳/影)」在幀中的比例 → 用來對齊地面線
  final double topFrac; // 內容「頂部(頭)」在幀中的比例 → 血條定位

  // 治療型敵人（如薩滿）：[healRange]>0 時，每 [healIntervalMs] 毫秒治療範圍內
  // 其他敵人，每次回復對方「最大血量 × [healFrac]」。healRange 以格為單位；0＝非治療型。
  final double healRange;
  final double healFrac;
  final int healIntervalMs;

  final bool pixel; // true＝像素風素材（Tiny Swords）→ 繪製用最近鄰、不模糊

  // 圖鑑預覽裁切微調（只影響 UI 預覽，不影響場上繪製）：
  // [avatarZoom]>1 裁更緊(放大)；[avatarDx]/[avatarDy] 以幀比例平移裁切中心。
  final double avatarZoom;
  final double avatarDx;
  final double avatarDy;

  static const grunt = EnemyKind(
    id: 'grunt',
    name: '雜兵',
    hpMul: 1.0,
    speedMul: 1.0,
    reward: 5,
    leakDamage: 1,
    color: Color(0xFF3F51B5),
    sizeMul: 1.0,
    unlockWave: 1,
    weight: 5,
    desc: '最基本的敵人，沒有特殊能力。',
    sheet: 'enemy_skull_run.png',
    frames: 6,
    frameSize: 192,
    footFrac: 0.677,
    topFrac: 0.286,
  );

  static const scout = EnemyKind(
    id: 'scout',
    name: '斥候',
    hpMul: 0.5,
    speedMul: 1.8,
    reward: 4,
    leakDamage: 1,
    color: Color(0xFFFFC107),
    sizeMul: 1.05,
    unlockWave: 3,
    weight: 3,
    desc: '騎豬的長槍哥布林，血少但移動很快。用減速（冰/雷）或渦流聚集後清除較有效。',
    sheet: 'enemy_pigrider_run.png',
    frames: 4,
    frameSize: 256,
    footFrac: 0.648,
    topFrac: 0.117,
    avatarZoom: 1.35, // 預覽放大聚焦騎士+坐騎，長槍裁掉
    avatarDy: 0.05, // 裁切中心往上，聚焦騎士
  );

  static const swarm = EnemyKind(
    id: 'swarm',
    name: '蟲群',
    hpMul: 0.25,
    speedMul: 1.2,
    reward: 2,
    leakDamage: 1,
    color: Color(0xFF4CAF50),
    sizeMul: 0.55,
    unlockWave: 5,
    weight: 4,
    desc: '血量極低但成群出現。用範圍攻擊（火炮/滾木/地刺）一次清最有效。',
    sheet: 'enemy_spider_run.png',
    frames: 5,
    frameSize: 192,
    footFrac: 0.708,
    topFrac: 0.281,
  );

  static const brute = EnemyKind(
    id: 'brute',
    name: '坦克',
    hpMul: 3.0,
    speedMul: 0.6,
    reward: 12,
    leakDamage: 2,
    color: Color(0xFFE53935),
    sizeMul: 1.4,
    unlockWave: 6,
    weight: 2,
    desc: '血厚、移動慢，漏過會扣 2 點生命。用持續傷害（毒/火）慢慢磨。',
    sheet: 'enemy_minotaur_walk.png',
    frames: 8,
    frameSize: 320,
    footFrac: 0.669,
    topFrac: 0.263,
  );

  /// Boss：巨獸。血量極高、移動慢、漏過重扣。本階段只做數值，
  /// 「擋停滾木 / 不被渦流吸」等機制留待互動型階段。只在 Boss 波手動生成，
  /// 不列入 [all]（不參與權重填充）。
  static const juggernaut = EnemyKind(
    id: 'juggernaut',
    name: '巨獸',
    hpMul: 8.0,
    speedMul: 0.5,
    reward: 60,
    leakDamage: 5,
    color: Color(0xFF4A148C),
    sizeMul: 2.2,
    unlockWave: 999,
    weight: 0,
    desc: '極高血量、移動緩慢的 Boss，漏過會重扣生命。集中火力或用持續傷害對付。',
    sheet: 'enemy_troll_walk.png',
    frames: 10,
    frameSize: 384,
    footFrac: 0.773,
    topFrac: 0.234,
    avatarZoom: 1.2,
    avatarDy: -0.1,
  );

  /// 薩滿（Tiny Swords「Hex Shaman」像素素材）：治療型支援敵人。定期回復周圍
  /// 其他敵人血量 → 逼玩家優先集火它，否則整群會被奶回來。血量中上、移速略慢。
  static const shaman = EnemyKind(
    id: 'shaman',
    name: '薩滿',
    hpMul: 1.5,
    speedMul: 0.85,
    reward: 15,
    leakDamage: 1,
    color: Color(0xFF26C6A0),
    sizeMul: 1.2,
    unlockWave: 8,
    weight: 1.5,
    desc: '會定期治療周圍的敵人（腳下有綠色治療光環）。優先集火解決它，否則整群會被奶回來。',
    sheet: 'enemy_shaman_run.png',
    frames: 4,
    frameSize: 192,
    footFrac: 0.71,
    topFrac: 0.24,
    pixel: true,
    healRange: 2.5,
    healFrac: 0.06,
    healIntervalMs: 1100,
  );

  /// 會參與波次「權重填充」的一般種類（依解鎖順序）。
  static const all = [grunt, scout, swarm, brute, shaman];
}

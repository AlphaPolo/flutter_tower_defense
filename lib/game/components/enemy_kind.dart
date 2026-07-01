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
  );

  static const scout = EnemyKind(
    id: 'scout',
    name: '斥候',
    hpMul: 0.5,
    speedMul: 1.8,
    reward: 4,
    leakDamage: 1,
    color: Color(0xFFFFC107),
    sizeMul: 0.7,
    unlockWave: 3,
    weight: 3,
    desc: '血少但移動很快。用減速（冰/雷）或渦流聚集後清除較有效。',
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
  );

  /// 第一階段的所有種類（依解鎖順序）。
  static const all = [grunt, scout, swarm, brute];
}

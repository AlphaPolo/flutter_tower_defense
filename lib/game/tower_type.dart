import 'dart:math';

/// 防禦塔 / 陷阱 / 障礙物種類。取代舊的 BuildingModel 子型別判斷。
enum TowerType {
  freezing,
  flame,
  airBlade,
  thunder,
  cannon,
  poison,
  log,
  spike,
  vortex,
  obstacle,
}

/// 陷阱類：蓋在地面、不阻擋敵人（不進 towers Map，尋路看不到），
/// 可蓋在敵人路徑上，靠敵人經過 / 週期觸發。
const Set<TowerType> kTrapTypes = {TowerType.spike, TowerType.vortex};

bool isTrapType(TowerType type) => kTrapTypes.contains(type);

/// 每種塔的數值與說明（給 UI 與元件共用，數值集中一處）。
class TowerStats {
  final int cost;
  final double range;
  final double damage;
  final int fireCD;
  final String title;
  final String description;

  const TowerStats({
    required this.cost,
    required this.range,
    required this.damage,
    required this.fireCD,
    required this.title,
    required this.description,
  });
}

const Map<TowerType, TowerStats> kTowerStats = {
  TowerType.freezing: TowerStats(
    cost: 30, // 基礎費砍半（升級系統）
    range: 2.5,
    damage: 10,
    fireCD: 1500,
    title: '冰凍塔',
    description: '減緩範圍內的敵人；升級可增強減速並擴大冰環',
  ),
  TowerType.flame: TowerStats(
    cost: 30,
    range: 4,
    damage: 8, // 灼燒 DPS（Lv1）；依 dt 結算、不受 fps 影響。升級提升
    fireCD: 100,
    title: '火焰塔',
    description: '噴射直線火焰持續灼燒；升級可加長射程與提高傷害',
  ),
  TowerType.airBlade: TowerStats(
    cost: 30,
    range: 2.5,
    damage: 12.5, // 每刀傷害；旋轉圈數依等級（見 AirBladeTowerComponent）
    fireCD: 0, // 風刃為旋轉掃擊，不使用冷卻
    title: '風刃塔',
    description: '旋轉風刃掃到即傷害；升級可轉更快、範圍更大',
  ),
  TowerType.thunder: TowerStats(
    cost: 35, // 基礎費砍半（升級系統）
    range: 2,
    damage: 10,
    fireCD: 2000,
    title: '雷電塔',
    description: '單體電擊、自帶微弱麻痺；升級可解鎖連鎖電鏈並強化麻痺',
  ),
  TowerType.cannon: TowerStats(
    cost: 45, // 基礎費砍半
    range: 4,
    damage: 40,
    fireCD: 1400,
    title: '火炮塔',
    description: '砲彈落地爆炸傷害範圍內敵人；升級可擴大範圍、中心加成',
  ),
  TowerType.poison: TowerStats(
    cost: 30, // 基礎費砍半
    range: 3.5,
    damage: 60, // 中毒總傷(Lv1，3 秒內)；升級提高。實際 dps 另加「每秒 %血量」
    fireCD: 1200,
    title: '毒塔',
    description: '中毒 3 秒（固定毒傷 + 每秒依最大血量%扣血）；升級提高毒傷與%傷害',
  ),
  TowerType.log: TowerStats(
    cost: 50, // 基礎費砍半
    range: 5,
    damage: 40, // Lv1 傷害；升級提高
    fireCD: 3000, // Lv1 發射間隔；Lv3 縮短
    title: '滾木塔',
    description: '朝玩家設定方向滾出巨木壓過敵人；升級提高傷害、縮短間隔',
  ),
  TowerType.spike: TowerStats(
    cost: 30,
    range: 1.0,
    damage: 12,
    fireCD: 450,
    title: '地刺',
    description: '埋設在地面的尖刺。不會阻擋敵人前進，敵人經過時持續受到傷害。',
  ),
  TowerType.vortex: TowerStats(
    cost: 40,
    range: 1.5,
    damage: 0,
    fireCD: 0, // 渦流的吸引週期在 VortexTrapComponent 內以常數控制
    title: '渦流陷阱',
    description: '持續把周圍的敵人緩慢吸聚成一團（不造成傷害、不阻擋前進），方便範圍攻擊一網打盡。',
  ),
  TowerType.obstacle: TowerStats(
    cost: 20,
    range: 0,
    damage: 0,
    fireCD: 0,
    title: '障礙物',
    description: '單純阻擋敵人前進的方向，沒有傷害敵人的行為',
  ),
};

TowerStats statsOf(TowerType type) => kTowerStats[type]!;

/// 升級樹的一個節點（Lv2 分支或 Lv3 葉）。
///
/// [key] 給塔判斷選了哪條（'A'/'B'/'A1'…）；[mods] 是「有效數值覆寫」——實際數字
/// 集中在這裡，塔的 getter 只用 `mod('key', base)` 讀。Lv2 節點的 [children] 是它底
/// 下的兩個 Lv3 節點；葉節點 [children] 為空。
class TowerUpgradeNode {
  const TowerUpgradeNode({
    required this.key,
    required this.name,
    required this.cost,
    required this.desc,
    this.mods = const {},
    this.children = const [],
  });

  final String key;
  final String name;
  final int cost;
  final String desc;
  final Map<String, double> mods;
  final List<TowerUpgradeNode> children;
}

/// 各塔的升級樹（Model B 分支）：root = 2 個 Lv2 分支，各帶 2 個 Lv3 子節點。
/// 玩家 Lv2 二擇一（選了就鎖），Lv3 再從所選分支底下二擇一 → 每塔 4 種 build。
/// 沒列出的塔不可升級。數字皆為起始值、可再調。
const Map<TowerType, List<TowerUpgradeNode>> kTowerUpgradeTree = {
  // 冰凍：A 減速強度 / B 範圍。base slow .6, range 2.5, fdur 2000
  TowerType.freezing: [
    TowerUpgradeNode(key: 'A', name: '深寒', cost: 30, desc: '減速更強', mods: {
      'slow': 0.4
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '絕對零度', cost: 45, desc: '減速極強，幾乎凍住', mods: {'slow': 0.12}),
      TowerUpgradeNode(
          key: 'A2', name: '冰封', cost: 45, desc: '強減速，且冰環維持更久', mods: {'slow': 0.2, 'fdur': 3200}),
    ]),
    TowerUpgradeNode(key: 'B', name: '霜域', cost: 30, desc: '冰環範圍加大', mods: {
      'range': 3.5
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '暴風雪', cost: 45, desc: '範圍再大幅擴張', mods: {'range': 4.6}),
      TowerUpgradeNode(
          key: 'B2', name: '霜牢', cost: 45, desc: '範圍加大且減速增強', mods: {'range': 3.9, 'slow': 0.4}),
    ]),
  ],
  // 火焰：A 傷害 / B 射程。base dmg 8, range 4
  TowerType.flame: [
    TowerUpgradeNode(key: 'A', name: '烈焰', cost: 30, desc: '灼燒 DPS 提升', mods: {
      'dmg': 12
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '熔核', cost: 45, desc: '灼燒 DPS 大幅提升', mods: {'dmg': 20}),
      TowerUpgradeNode(
          key: 'A2', name: '爆燃', cost: 45, desc: 'DPS 提升且射程加長', mods: {'dmg': 16, 'range': 5}),
    ]),
    TowerUpgradeNode(key: 'B', name: '長焰', cost: 30, desc: '火焰射程加長', mods: {
      'range': 6
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '火龍吐息', cost: 45, desc: '射程再大幅加長', mods: {'range': 8}),
      TowerUpgradeNode(
          key: 'B2', name: '熾流', cost: 45, desc: '射程加長且 DPS 提升', mods: {'range': 7, 'dmg': 12}),
    ]),
  ],
  // 風刃：A 轉速 / B 範圍。base spin 4π, range 2.5
  TowerType.airBlade: [
    TowerUpgradeNode(key: 'A', name: '疾風', cost: 30, desc: '旋轉更快、每秒更多刀', mods: {
      'spin': 6 * pi
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '狂風', cost: 45, desc: '旋轉極快', mods: {'spin': 8 * pi}),
      TowerUpgradeNode(
          key: 'A2', name: '亂舞', cost: 45, desc: '轉速提升且範圍加大', mods: {'spin': 7 * pi, 'range': 3.0}),
    ]),
    TowerUpgradeNode(key: 'B', name: '巨刃', cost: 30, desc: '攻擊範圍加大', mods: {
      'range': 3.2
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '大回旋', cost: 45, desc: '範圍再加大', mods: {'range': 4.0}),
      TowerUpgradeNode(
          key: 'B2', name: '廣掃', cost: 45, desc: '範圍加大且轉速提升', mods: {'range': 3.6, 'spin': 6 * pi}),
    ]),
  ],
  // 雷電：A 連鎖 / B 麻痺。base chain 1, pchance .1, pms 120, dmg 10
  TowerType.thunder: [
    TowerUpgradeNode(key: 'A', name: '電鏈', cost: 35, desc: '啟用連鎖，一次串到 3 名敵人', mods: {
      'chain': 3
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '閃電風暴', cost: 55, desc: '連結上限提升到 6', mods: {'chain': 6}),
      TowerUpgradeNode(
          key: 'A2', name: '過載', cost: 55, desc: '連結到 4 且單擊傷害提高', mods: {'chain': 4, 'dmg': 16}),
    ]),
    TowerUpgradeNode(key: 'B', name: '麻痺', cost: 35, desc: '麻痺機率與時間提升', mods: {
      'pchance': 0.3,
      'pms': 300
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '電癱', cost: 55, desc: '麻痺機率與時間大幅提升', mods: {'pchance': 0.6, 'pms': 600}),
      TowerUpgradeNode(
          key: 'B2', name: '感電', cost: 55, desc: '麻痺提升，並可連結 2 名敵人', mods: {'pchance': 0.4, 'pms': 350, 'chain': 2}),
    ]),
  ],
  // 火炮：A 爆炸範圍 / B 中心加成。base blast 1.2, center 0
  TowerType.cannon: [
    TowerUpgradeNode(key: 'A', name: '大口徑', cost: 45, desc: '爆炸範圍加大', mods: {
      'blast': 1.9
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '飽和轟炸', cost: 70, desc: '爆炸範圍極大', mods: {'blast': 2.7}),
      TowerUpgradeNode(
          key: 'A2', name: '齊射', cost: 70, desc: '範圍加大且中心加成(最高1.6×)', mods: {'blast': 2.2, 'center': 0.6}),
    ]),
    TowerUpgradeNode(key: 'B', name: '高爆', cost: 45, desc: '中心加成，最高 2 倍傷害', mods: {
      'center': 1.0
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '穿甲', cost: 70, desc: '中心加成最高 2.5 倍', mods: {'center': 1.5}),
      TowerUpgradeNode(
          key: 'B2', name: '破片', cost: 70, desc: '中心加成且範圍加大', mods: {'center': 0.8, 'blast': 2.0}),
    ]),
  ],
  // 毒：A 固定毒傷 / B %最大血量。base pdmg 60, pct .01, pdur 3000
  TowerType.poison: [
    TowerUpgradeNode(key: 'A', name: '劇毒', cost: 30, desc: '中毒總傷提高', mods: {
      'pdmg': 100
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '猛毒', cost: 45, desc: '中毒總傷大幅提高', mods: {'pdmg': 180}),
      TowerUpgradeNode(
          key: 'A2', name: '蔓毒', cost: 45, desc: '總傷提高且中毒更持久', mods: {'pdmg': 130, 'pdur': 4200}),
    ]),
    TowerUpgradeNode(key: 'B', name: '蝕血', cost: 30, desc: '每秒%最大血量傷害提升', mods: {
      'pct': 0.03
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '深蝕', cost: 45, desc: '%血量傷害大幅提升', mods: {'pct': 0.06}),
      TowerUpgradeNode(
          key: 'B2', name: '衰血', cost: 45, desc: '%血量傷害提升且加固定毒傷', mods: {'pct': 0.04, 'pdmg': 100}),
    ]),
  ],
  // 滾木：A 傷害 / B 發射頻率。base dmg 40, cd 3000
  TowerType.log: [
    TowerUpgradeNode(key: 'A', name: '巨木', cost: 50, desc: '滾木傷害提高', mods: {
      'dmg': 60
    }, children: [
      TowerUpgradeNode(
          key: 'A1', name: '巨岩', cost: 75, desc: '滾木傷害大幅提高', mods: {'dmg': 100}),
      TowerUpgradeNode(
          key: 'A2', name: '重木', cost: 75, desc: '傷害提高且發射變快', mods: {'dmg': 80, 'cd': 2400}),
    ]),
    TowerUpgradeNode(key: 'B', name: '連發', cost: 50, desc: '發射間隔縮短', mods: {
      'cd': 2200
    }, children: [
      TowerUpgradeNode(
          key: 'B1', name: '速射', cost: 75, desc: '發射間隔大幅縮短', mods: {'cd': 1500}),
      TowerUpgradeNode(
          key: 'B2', name: '疾木', cost: 75, desc: '發射變快且傷害提高', mods: {'cd': 1800, 'dmg': 60}),
    ]),
  ],
};

/// 該塔的最高等級（1 = 不可升級；有升級樹的塔皆為 3 級）。
int maxLevelOf(TowerType type) => kTowerUpgradeTree.containsKey(type) ? 3 : 1;

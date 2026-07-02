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

/// 一個升級選項（給 UI 顯示名稱/費用/說明；實際效果邏輯在各塔的 level getter）。
class TowerUpgrade {
  const TowerUpgrade({
    required this.name,
    required this.cost,
    required this.desc,
  });

  final String name;
  final int cost;
  final String desc;
}

/// 各塔的升級路線（index 0 = Lv1→Lv2、index 1 = Lv2→Lv3…）。
/// 沒列出的塔目前不可升級。
const Map<TowerType, List<TowerUpgrade>> kTowerUpgrades = {
  TowerType.thunder: [
    TowerUpgrade(name: '電鏈', cost: 35, desc: '啟用連鎖，一次串到 3 名敵人'),
    TowerUpgrade(
        name: '過載', cost: 55, desc: '連結上限提升到 5，麻痺機率與時間大幅提升'),
  ],
  TowerType.freezing: [
    TowerUpgrade(name: '深寒', cost: 30, desc: '減速更強、冰環範圍加大'),
    TowerUpgrade(name: '凍結', cost: 45, desc: '減速極強、冰環更大'),
  ],
  TowerType.flame: [
    TowerUpgrade(name: '長焰', cost: 30, desc: '火焰射程加長'),
    TowerUpgrade(name: '烈焰', cost: 45, desc: '灼燒 DPS 提升'),
  ],
  TowerType.airBlade: [
    TowerUpgrade(name: '疾風', cost: 30, desc: '刀刃旋轉更快、每秒更多刀'),
    TowerUpgrade(name: '巨刃', cost: 45, desc: '攻擊範圍加大'),
  ],
  TowerType.cannon: [
    TowerUpgrade(name: '大口徑', cost: 45, desc: '爆炸範圍加大'),
    TowerUpgrade(name: '高爆', cost: 70, desc: '爆炸中心加成，最高 2 倍傷害'),
  ],
  TowerType.poison: [
    TowerUpgrade(name: '劇毒', cost: 30, desc: '中毒總傷提高，每秒%血量傷害提升'),
    TowerUpgrade(name: '蔓延', cost: 45, desc: '中毒總傷再提高，每秒%血量傷害大幅提升'),
  ],
  TowerType.log: [
    TowerUpgrade(name: '巨木', cost: 50, desc: '滾木傷害提高'),
    TowerUpgrade(name: '連發', cost: 75, desc: '發射間隔縮短'),
  ],
};

/// 該塔的最高等級（1 = 不可升級）。
int maxLevelOf(TowerType type) => 1 + (kTowerUpgrades[type]?.length ?? 0);

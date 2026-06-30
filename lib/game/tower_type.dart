/// 防禦塔 / 陷阱 / 障礙物種類。取代舊的 BuildingModel 子型別判斷。
enum TowerType {
  freezing,
  flame,
  airBlade,
  thunder,
  cannon,
  poison,
  spike,
  obstacle,
}

/// 陷阱類：蓋在地面、不阻擋敵人（不進 towers Map，尋路看不到），
/// 可蓋在敵人路徑上，靠敵人經過時觸發。
const Set<TowerType> kTrapTypes = {TowerType.spike};

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
    cost: 60,
    range: 3.0,
    damage: 10,
    fireCD: 1500,
    title: '冰凍塔',
    description: '傷害較低但能夠減緩周圍的敵人',
  ),
  TowerType.flame: TowerStats(
    cost: 60,
    range: 6,
    damage: 0.2,
    fireCD: 100,
    title: '火焰塔',
    description: '能夠噴射一直線的火焰，使其在直線範圍上的敵人受到持續地延燒傷害',
  ),
  TowerType.airBlade: TowerStats(
    cost: 60,
    range: 3,
    damage: 7,
    fireCD: 300,
    title: '風刃塔',
    description: '能夠製造旋轉的風刃對周圍的敵人造成不錯的劈砍傷害',
  ),
  TowerType.thunder: TowerStats(
    cost: 70,
    range: 2,
    damage: 10,
    fireCD: 2000,
    title: '雷電塔',
    description: '能夠在敵人之間製造連鎖的電鏈一起受到電擊傷害，並有機率麻痺該敵人',
  ),
  TowerType.cannon: TowerStats(
    cost: 90,
    range: 4,
    damage: 25,
    fireCD: 1400,
    title: '火炮塔',
    description: '發射砲彈命中後爆炸，對落點周圍範圍內的所有敵人造成傷害',
  ),
  TowerType.poison: TowerStats(
    cost: 80,
    range: 3.5,
    damage: 18,
    fireCD: 1200,
    title: '毒塔',
    description: '射出毒液使敵人中毒，在數秒內持續受到毒素傷害',
  ),
  TowerType.spike: TowerStats(
    cost: 30,
    range: 1.0,
    damage: 12,
    fireCD: 450,
    title: '地刺',
    description: '埋設在地面的尖刺。不會阻擋敵人前進，敵人經過時持續受到傷害。',
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

/// 防禦塔種類。取代舊的 BuildingModel 子型別判斷。
enum TowerType {
  freezing,
  flame,
  airBlade,
  thunder,
  obstacle,
}

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

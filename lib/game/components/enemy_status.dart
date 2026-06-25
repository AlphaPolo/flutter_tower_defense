/// 敵人的數值狀態（血量、速度）。不可變，每次變動產生新的副本。
class EnemyStatus {
  final double totalHp;
  final double currentHp;
  final double speed;

  const EnemyStatus({
    required this.totalHp,
    required this.currentHp,
    required this.speed,
  });

  EnemyStatus copyWith({
    double? totalHp,
    double? currentHp,
    double? speed,
  }) {
    return EnemyStatus(
      totalHp: totalHp ?? this.totalHp,
      currentHp: currentHp ?? this.currentHp,
      speed: speed ?? this.speed,
    );
  }

  EnemyStatus add({double? hp, double? speed}) {
    return copyWith(
      currentHp: hp == null ? null : currentHp + hp,
      speed: speed == null ? null : this.speed + speed,
    );
  }

  EnemyStatus sub({double? hp, double? speed}) {
    return copyWith(
      currentHp: hp == null ? null : currentHp - hp,
      speed: speed == null ? null : this.speed - speed,
    );
  }
}

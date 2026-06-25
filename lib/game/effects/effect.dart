import '../../model/effects/effect_duplicate_type.dart';
import '../../model/effects/stat_calc_type.dart';
import '../components/enemy_status.dart';

export '../../model/effects/effect_duplicate_type.dart';
export '../../model/effects/stat_calc_type.dart';

/// 套在敵人身上的狀態效果（減速、麻痺…）。
///
/// 與舊版相比，移除了對 Enemy / GameManager 的依賴：calc 只吃 EnemyStatus，
/// 計時用毫秒。
abstract class BaseEffect implements Comparable<BaseEffect> {
  void onAttach() {}
  void onEnd() {}

  void tick(int dtMillis);

  /// 把效果套用到當前狀態上，回傳修改後的狀態。
  EnemyStatus calc(EnemyStatus status);

  bool get dead;

  /// 套用順序（數字小的先算）。
  int get order;

  /// 判斷是否為同一種效果，以及重疊時如何處理。
  IdWithEffectType get idWithType;

  @override
  int compareTo(BaseEffect other) => order.compareTo(other.order);

  bool isSameId(BaseEffect other) =>
      idWithType.sameTypeId == other.idWithType.sameTypeId;
}

/// 基本的「持續一段時間」效果。
abstract class DefaultTimerEffect extends BaseEffect {
  DefaultTimerEffect(this.lifetime);

  int clock = 0;
  int lifetime;

  @override
  bool dead = false;

  @override
  void tick(int dtMillis) {
    clock += dtMillis;
    if (dead) return;
    if (clock >= lifetime) dead = true;
  }
}

/// 減速 / 麻痺效果。依 [StatCalcType] 對速度做運算。
class SlowMovementEffect extends DefaultTimerEffect {
  SlowMovementEffect(
    this.idWithType,
    super.lifetime,
    this.type,
    this.value,
  );

  SlowMovementEffect.multi(
    this.idWithType,
    super.lifetime,
    this.value,
  ) : type = StatCalcType.multi;

  SlowMovementEffect.sub(
    this.idWithType,
    super.lifetime,
    this.value,
  ) : type = StatCalcType.sub;

  SlowMovementEffect.flat(
    this.idWithType,
    super.lifetime,
    this.value, [
    this._order = 300,
  ]) : type = StatCalcType.flat;

  StatCalcType type;
  double value;
  int _order = 200;

  @override
  final IdWithEffectType idWithType;

  @override
  EnemyStatus calc(EnemyStatus status) {
    final afterModifier = type.calc(status.speed, value);
    return status.copyWith(speed: afterModifier);
  }

  @override
  int get order => _order;
}

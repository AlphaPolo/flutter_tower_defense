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

  /// 這一幀要對敵人造成的持續傷害（毒等），取出後歸零。預設 0。
  double takeDamage() => 0;

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

/// 流血：可疊層的持續傷害。每疊一層 [perStackDps]，總 DPS = 層數 × perStackDps；
/// 每次被割到 [refresh] 疊一層(上限 [maxStacks])並重置壽命，太久沒被割到就整組消失。
class BleedEffect extends DefaultTimerEffect {
  BleedEffect(this.idWithType, super.lifetime, this.perStackDps, this.maxStacks);

  final IdWithEffectType idWithType;
  final double perStackDps;
  final int maxStacks;
  int stacks = 1;

  static const int _tickMs = 200;
  int _acc = 0;
  double _pending = 0;

  /// 再疊一層並重置壽命。
  void refresh(int durationMs) {
    if (stacks < maxStacks) stacks++;
    clock = 0;
    lifetime = durationMs;
    dead = false;
  }

  @override
  void tick(int dtMillis) {
    super.tick(dtMillis);
    _acc += dtMillis;
    while (_acc >= _tickMs) {
      _acc -= _tickMs;
      _pending += perStackDps * stacks * _tickMs / 1000.0;
    }
  }

  @override
  double takeDamage() {
    final d = _pending;
    _pending = 0;
    return d;
  }

  @override
  EnemyStatus calc(EnemyStatus status) => status;

  @override
  int get order => 450;
}

/// 脆弱化：不改屬性、不造成傷害，只在敵人受到「物理」傷害時放大傷害
/// （放大邏輯在 EnemyComponent.dealDamage）。多個重疊取最強。
class VulnerableEffect extends DefaultTimerEffect {
  VulnerableEffect(this.idWithType, super.lifetime, this.physicalAmp);

  /// 物理受傷加成，例如 0.35 = 受物理攻擊多吃 35% 傷害。
  final double physicalAmp;

  @override
  final IdWithEffectType idWithType;

  @override
  EnemyStatus calc(EnemyStatus status) => status;

  @override
  int get order => 500;
}

/// 中毒：持續一段時間，每秒造成 [dps] 點傷害（依幀累積後交給敵人扣血）。
class PoisonEffect extends DefaultTimerEffect {
  PoisonEffect(this.idWithType, super.lifetime, this.dps);

  final double dps;

  /// 每隔多久結算一次毒傷（ms）。
  static const int _tickMs = 200;
  int _acc = 0; // 距離上次結算累積的時間
  double _pending = 0;

  @override
  final IdWithEffectType idWithType;

  @override
  void tick(int dtMillis) {
    super.tick(dtMillis);
    // 每 0.2 秒才扣一次血（每次 dps × 0.2），而非逐幀平滑扣。
    _acc += dtMillis;
    while (_acc >= _tickMs) {
      _acc -= _tickMs;
      _pending += dps * _tickMs / 1000.0;
    }
  }

  @override
  double takeDamage() {
    final d = _pending;
    _pending = 0;
    return d;
  }

  @override
  EnemyStatus calc(EnemyStatus status) => status; // 不改數值，只造成傷害

  @override
  int get order => 400;
}

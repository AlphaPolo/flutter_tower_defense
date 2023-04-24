import '../../manager/game_manager.dart';
import '../enemy/enemy.dart';
import 'base_effect.dart';
import 'state_modifier.dart';

class SlowMovementEffect extends DefaultTimerEffect {
  SlowMovementEffect(
    super.lifetime,
    this.target,
    this.type,
    this.value,
  );

  SlowMovementEffect.multi(
    super.lifetime,
    this.target,
    this.value,
  ) : type = StatCalcType.multi;

  SlowMovementEffect.sub(
      super.lifetime,
      this.target,
      this.value,
  ) : type = StatCalcType.sub;

  SlowMovementEffect.flat(
      super.lifetime,
      this.target,
      this.value,
      this._order,
  ) : type = StatCalcType.flat;

  Enemy target;
  StatCalcType type;
  double value;
  int _order = 200;

  @override
  EnemyStatus calc(GameManager manager, EnemyStatus status) {
    final originSpeed = status.speed;
    final afterModifier = type.calc(originSpeed, value);
    return status.copyWith(speed: afterModifier);
  }

  @override
  int get order => _order;
}

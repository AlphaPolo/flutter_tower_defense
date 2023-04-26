import 'package:tower_defense/model/effects/effect_duplicate_type.dart';

import '../../manager/game_manager.dart';
import '../enemy/enemy.dart';
import 'base_effect.dart';
import 'stat_calc_type.dart';

class SlowMovementEffect extends DefaultTimerEffect {
  SlowMovementEffect(
    this.idWithType,
    super.lifetime,
    this.target,
    this.type,
    this.value,
  );

  SlowMovementEffect.multi(
    this.idWithType,
    super.lifetime,
    this.target,
    this.value,
  ) : type = StatCalcType.multi;

  SlowMovementEffect.sub(
      this.idWithType,
      super.lifetime,
      this.target,
      this.value,
  ) : type = StatCalcType.sub;

  SlowMovementEffect.flat(
      this.idWithType,
      super.lifetime,
      this.target,
      this.value,
      [this._order = 300]
  ) : type = StatCalcType.flat;

  Enemy target;
  StatCalcType type;
  double value;
  int _order = 200;

  @override
  final IdWithEffectType idWithType;

  @override
  EnemyStatus calc(GameManager manager, EnemyStatus status) {
    final originSpeed = status.speed;
    final afterModifier = type.calc(originSpeed, value);
    return status.copyWith(speed: afterModifier);
  }

  @override
  int get order => _order;

}

enum EffectDuplicateStrategy {
  none,
  last,
  strongest,
}

class IdWithEffectType {

  /// 表示同一種的狀態
  final int sameTypeId;

  /// 同種狀態撞到了應該如何處理
  final EffectDuplicateStrategy duplicateStrategy;

  const IdWithEffectType(this.sameTypeId, this.duplicateStrategy);

}
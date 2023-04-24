enum StatCalcType
{
  add,
  sub,
  multi,
  divide,
  /// 絕對值
  flat;

  double calc(double l, double r) {
    switch(this) {
      case StatCalcType.add: return l + r;
      case StatCalcType.sub: return l - r;
      case StatCalcType.multi: return l * r;
      case StatCalcType.divide: return l / r;
      case StatCalcType.flat: return r;
    }
  }
}
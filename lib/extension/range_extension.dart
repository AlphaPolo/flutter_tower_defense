extension RangeExtension on int {
  /// 取得 x 到 y 之間的數 (y 包含)
  ///
  /// Example:
  ///
  /// ```dart
  /// final numbers = 0.upTo(5);
  /// numbers.forEach(print);
  /// // 0
  /// // 1
  /// // 2
  /// // 3
  /// // 4
  /// // 5
  /// ```

  Iterable<int> upTo(int maxInclusive) sync* {
    int current = this;
    while(current <= maxInclusive) {
      yield(current);
      current++;
    }
  }

  bool isBetween(int start, end) {
    return start < this && this < end;
  }
}
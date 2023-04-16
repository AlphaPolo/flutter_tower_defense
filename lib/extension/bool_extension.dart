extension BoolExtension on bool? {
  /// if you need to check nullable bool you can use this
  /// example:
  /// ```dart
  /// bool? isOnline
  ///
  /// isOnline = null
  /// print(isOnline.isTrue)      // false
  ///
  /// isOnline = true
  /// print(isOnline.isTrue)      // true
  ///
  /// isOnline = false
  /// print(isOnline.isTrue)      // false
  /// ```
  bool get isTrue => this ?? false;
}
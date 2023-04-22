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
  bool get isTrue => this == true;

  /// if you need to check nullable bool you can use this,
  /// this mean bool is false or null
  /// example:
  /// ```dart
  /// bool? isOnline
  ///
  /// isOnline = null
  /// print(isOnline.isNotTrue)      // true
  ///
  /// isOnline = true
  /// print(isOnline.isNotTrue)      // false
  ///
  /// isOnline = false
  /// print(isOnline.isNotTrue)      // true
  /// ```
  bool get isNotTrue => this != true;
}
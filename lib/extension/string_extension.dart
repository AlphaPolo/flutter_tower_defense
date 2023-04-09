import 'package:tower_defense/extension/kotlin_like_extensions.dart';
// import 'package:intl/intl.dart';

extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
            r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
        .hasMatch(this);
  }
}

// extension DateParser on String {
//   static const String defaultFormat = 'yyyy-MM-dd HH:mm:ss';
//
//   DateTime parseToDate({String format = defaultFormat}) => DateFormat(format).parse(this);
// }

extension ObjectParser on String {
  List<T> splitMapJoinTo<T>(
    Pattern pattern, {
    T? Function(Match)? onMatch,
    T? Function(String)? onNonMatch,
  }) {
    final result = <T>[];
    splitMapJoin(
      pattern,
      onMatch: (match) {
        onMatch?.call(match)?.let(result.add);
        return '';
      },
      onNonMatch: (text) {
        onNonMatch?.call(text)?.let(result.add);
        return '';
      }
    );
    return result;
  }

  List<T> splitMapJoinToRegexMatch<T>(
      RegExp regExp, {
        T? Function(RegExpMatch)? onMatch,
        T? Function(String)? onNonMatch,
      }) {
    final result = <T>[];

    final matches = regExp.allMatches(this);

    /// 處理字串直到分割完畢
    int index = 0;
    for (final match in matches) {
      final nonMatch = substring(index, match.start);

      /// 沒有 match 到的 callback
      if(nonMatch.isNotEmpty) onNonMatch?.call(nonMatch)?.let(result.add);

      /// match 到的 callback
      onMatch?.call(match)?.let(result.add);

      /// 移動指針位置
      index = match.end;
    }

    /// 如果還有剩餘未 match 到的字串
    if(index < length) {    /// length -1 表示如果進來就起碼會有 1 個字元
      final nonMatch = substring(index);
      onNonMatch?.call(nonMatch)?.let(result.add);
    }
    return result;
  }

  /// onNonMatch with start end
  List<T> splitMapJoinWithNonIndex<T>(
      RegExp regExp, {
        T? Function(RegExpMatch)? onMatch,
        T? Function(String, int, int)? onNonMatch,
      }) {
    final result = <T>[];

    final matches = regExp.allMatches(this);

    /// 處理字串直到分割完畢
    int index = 0;
    for (final match in matches) {
      final nonMatch = substring(index, match.start);

      /// 沒有 match 到的 callback
      if(nonMatch.isNotEmpty) onNonMatch?.call(nonMatch, index, match.start)?.let(result.add);

      /// match 到的 callback
      onMatch?.call(match)?.let(result.add);

      /// 移動指針位置
      index = match.end;
    }

    /// 如果還有剩餘未 match 到的字串
    if(index < length - 1) {    /// length -1 表示如果進來就起碼會有 1 個字元
      final nonMatch = substring(index);
      onNonMatch?.call(nonMatch, index, length)?.let(result.add);
    }
    return result;
  }
}

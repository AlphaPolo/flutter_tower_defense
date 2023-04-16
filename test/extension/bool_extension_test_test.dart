import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/extension/bool_extension.dart';

void main() {
  group('bool extension test', () {
    bool? isOnline;
    test('isOnline is null', () {
      isOnline = null;
      expect(isOnline.isTrue, isFalse);
    });

    test('isOnline is true', () {
      isOnline = true;
      expect(isOnline.isTrue, isTrue);
    });

    test('isOnline is false', () {
      isOnline = null;
      expect(isOnline.isTrue, isFalse);
    });
  });
}
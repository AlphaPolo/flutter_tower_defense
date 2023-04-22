import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/extension/bool_extension.dart';

void main() {
  group('isTrue test', () {
    bool? isOnline;
    test('isOnline is null get false', () {
      isOnline = null;
      expect(isOnline.isTrue, isFalse);
    });

    test('isOnline is true get true', () {
      isOnline = true;
      expect(isOnline.isTrue, isTrue);
    });

    test('isOnline is false get false', () {
      isOnline = false;
      expect(isOnline.isTrue, isFalse);
    });
  });

  group('ifNotTrue test', () {
    bool? isOnline;
    test('isOnline is null get true', () {
      isOnline = null;
      expect(isOnline.isNotTrue, isTrue);
    });

    test('isOnline is true', () {
      isOnline = true;
      expect(isOnline.isNotTrue, isFalse);
    });

    test('isOnline is false', () {
      isOnline = false;
      expect(isOnline.isNotTrue, isTrue);
    });
  });
}
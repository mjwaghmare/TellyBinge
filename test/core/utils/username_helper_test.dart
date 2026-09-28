import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/utils/username_helper.dart';

void main() {
  group('generateUsername', () {
    test('cleans and lowercases alphanumeric name', () {
      expect(generateUsername('John Doe'), 'johndoe');
      expect(generateUsername('MovieFan_123!'), 'moviefan123');
    });

    test('pads single trailing digit with a leading zero', () {
      expect(generateUsername('mjwaghmare5'), 'mjwaghmare05');
      expect(generateUsername('cinephile1'), 'cinephile01');
    });

    test('does not pad multi-digit trailing numbers', () {
      expect(generateUsername('user42'), 'user42');
      expect(generateUsername('fan007'), 'fan007');
    });

    test('returns default fallback when name is null, empty, blank, or User', () {
      expect(generateUsername(null), 'user_popverse');
      expect(generateUsername(''), 'user_popverse');
      expect(generateUsername('   '), 'user_popverse');
      expect(generateUsername('User'), 'user_popverse');
    });

    test('preserves custom fallback when provided', () {
      expect(generateUsername(null, fallback: 'cinephile'), 'cinephile');
      expect(generateUsername('', fallback: 'cinephile'), 'cinephile');
      expect(generateUsername('   ', fallback: 'cinephile'), 'cinephile');
      expect(generateUsername('User', fallback: 'cinephile'), 'cinephile');
      expect(generateUsername('@@@###', fallback: 'cinephile'), 'cinephile');
    });

    test('cleans name when custom fallback is specified and name is valid', () {
      expect(generateUsername('Jane Foster', fallback: 'cinephile'), 'janefoster');
    });
  });
}

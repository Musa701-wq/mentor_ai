import 'package:flutter_test/flutter_test.dart';
import 'package:student_ai/services/creditService.dart';

void main() {
  group('CreditsService Tests', () {
    test('1000 tokens should be 1.0 credit', () {
      expect(CreditsService.calcCreditsFromTokens(1000), 1.0);
    });

    test('450 tokens should be 0.45 credit', () {
      expect(CreditsService.calcCreditsFromTokens(450), 0.45);
    });

    test('2500 tokens should be 2.5 credits', () {
      expect(CreditsService.calcCreditsFromTokens(2500), 2.5);
    });

    test('0 tokens should be 0.0 credit', () {
      expect(CreditsService.calcCreditsFromTokens(0), 0.0);
    });
  });
}

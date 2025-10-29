import 'package:flutter_test/flutter_test.dart';
import 'package:quick_spend/services/amount_parser.dart';
import 'package:quick_spend/services/language_detector.dart';
import 'package:quick_spend/services/categorizer.dart';
import 'package:quick_spend/services/expense_parser.dart';
import 'package:quick_spend/models/category.dart';

void main() {
  group('AmountParser', () {
    test('parses Vietnamese number words', () {
      expect(AmountParser.parseAmount('50 nghìn'), 50000.0);
      expect(AmountParser.parseAmount('1 triệu'), 1000000.0);
      expect(AmountParser.parseAmount('2.5 triệu'), 2500000.0);
    });

    test('parses k/m suffixes', () {
      expect(AmountParser.parseAmount('50k'), 50000.0);
      expect(AmountParser.parseAmount('1.5m'), 1500000.0);
      expect(AmountParser.parseAmount('100k'), 100000.0);
    });

    test('parses formatted numbers', () {
      expect(AmountParser.parseAmount('100,000'), 100000.0);
      expect(AmountParser.parseAmount('1,500,000'), 1500000.0);
    });

    test('parses plain numbers', () {
      expect(AmountParser.parseAmount('50000'), 50000.0);
      expect(AmountParser.parseAmount('1500000'), 1500000.0);
    });

    test('extracts amount and description', () {
      final result1 = AmountParser.extractAmount('50k coffee');
      expect(result1, isNotNull);
      expect(result1!.amount, 50000.0);
      expect(result1.description, 'coffee');

      final result2 = AmountParser.extractAmount('100 nghìn xăng');
      expect(result2, isNotNull);
      expect(result2!.amount, 100000.0);
      expect(result2.description, 'xăng');
    });
  });

  group('LanguageDetector', () {
    test('detects Vietnamese by diacritics', () {
      expect(LanguageDetector.detectLanguage('cà phê'), 'vi');
      expect(LanguageDetector.detectLanguage('phở'), 'vi');
      expect(LanguageDetector.detectLanguage('ăn trưa'), 'vi');
    });

    test('detects Vietnamese by keywords', () {
      expect(LanguageDetector.detectLanguage('xăng'), 'vi');
      expect(LanguageDetector.detectLanguage('mua sắm'), 'vi');
      expect(LanguageDetector.detectLanguage('100 nghìn'), 'vi');
    });

    test('defaults to English', () {
      expect(LanguageDetector.detectLanguage('coffee'), 'en');
      expect(LanguageDetector.detectLanguage('lunch'), 'en');
      expect(LanguageDetector.detectLanguage('groceries'), 'en');
    });

    test('returns confidence scores', () {
      final viConfidence = LanguageDetector.getConfidence('cà phê', 'vi');
      expect(viConfidence, greaterThan(0.5));

      final enConfidence = LanguageDetector.getConfidence('coffee', 'en');
      expect(enConfidence, greaterThan(0.5));
    });
  });

  group('Categorizer', () {
    test('categorizes food items in English', () {
      final result = Categorizer.categorize('coffee', 'en');
      expect(result.category, ExpenseCategory.food);
      expect(result.confidence, greaterThan(0.0));
    });

    test('categorizes food items in Vietnamese', () {
      final result = Categorizer.categorize('cà phê', 'vi');
      expect(result.category, ExpenseCategory.food);
      expect(result.confidence, greaterThan(0.0));
    });

    test('categorizes transport in English', () {
      final result = Categorizer.categorize('gas', 'en');
      expect(result.category, ExpenseCategory.transport);
    });

    test('categorizes transport in Vietnamese', () {
      final result = Categorizer.categorize('xăng', 'vi');
      expect(result.category, ExpenseCategory.transport);
    });

    test('categorizes shopping', () {
      final result = Categorizer.categorize('shopping', 'en');
      expect(result.category, ExpenseCategory.shopping);
    });

    test('defaults to other for unknown items', () {
      final result = Categorizer.categorize('unknown item', 'en');
      expect(result.category, ExpenseCategory.other);
      expect(result.confidence, 0.0);
    });

    test('returns multiple category suggestions', () {
      final results = Categorizer.getAllMatches('restaurant food', 'en');
      expect(results.length, greaterThan(0));
      expect(results.first.category, ExpenseCategory.food);
    });
  });

  group('ExpenseParser', () {
    test('parses English input correctly', () {
      final result = ExpenseParser.parse('50k coffee', 'user123');
      expect(result.success, true);
      expect(result.expense, isNotNull);
      expect(result.expense!.amount, 50000.0);
      expect(result.expense!.description, 'coffee');
      expect(result.expense!.category, ExpenseCategory.food);
      expect(result.language, 'en');
    });

    test('parses Vietnamese input correctly', () {
      final result = ExpenseParser.parse('100k xăng', 'user123');
      expect(result.success, true);
      expect(result.expense, isNotNull);
      expect(result.expense!.amount, 100000.0);
      expect(result.expense!.description, 'xăng');
      expect(result.expense!.category, ExpenseCategory.transport);
      expect(result.language, 'vi');
    });

    test('parses Vietnamese with number words', () {
      final result = ExpenseParser.parse('1.5 triệu mua sắm', 'user123');
      expect(result.success, true);
      expect(result.expense!.amount, 1500000.0);
      expect(result.expense!.description, 'mua sắm');
      expect(result.expense!.category, ExpenseCategory.shopping);
    });

    test('handles mixed English/Vietnamese', () {
      final result = ExpenseParser.parse('50k shopping', 'user123');
      expect(result.success, true);
      expect(result.expense!.amount, 50000.0);
    });

    test('returns error for empty input', () {
      final result = ExpenseParser.parse('', 'user123');
      expect(result.success, false);
      expect(result.errorMessage, isNotNull);
    });

    test('returns error for missing amount', () {
      final result = ExpenseParser.parse('just text', 'user123');
      expect(result.success, false);
      expect(result.errorMessage, contains('amount'));
    });

    test('allows category override', () {
      final result = ExpenseParser.parseWithCategory(
        '50k something',
        'user123',
        ExpenseCategory.entertainment,
      );
      expect(result.success, true);
      expect(result.expense!.category, ExpenseCategory.entertainment);
      expect(result.expense!.confidence, 1.0);
    });

    test('provides confidence scores', () {
      final result = ExpenseParser.parse('100k coffee', 'user123');
      expect(result.overallConfidence, isNotNull);
      expect(result.languageConfidence, isNotNull);
      expect(result.categoryConfidence, isNotNull);
    });

    test('provides alternative category suggestions', () {
      final result = ExpenseParser.parse('50k food', 'user123');
      expect(result.suggestedCategories, isNotNull);
      expect(result.suggestedCategories!.isNotEmpty, true);
    });
  });

  group('Integration Tests', () {
    test('handles complex Vietnamese input', () {
      final result = ExpenseParser.parse('200k ăn trưa nhà hàng', 'user123');
      expect(result.success, true);
      expect(result.expense!.amount, 200000.0);
      expect(result.expense!.category, ExpenseCategory.food);
      expect(result.language, 'vi');
    });

    test('handles formatted amounts', () {
      final result = ExpenseParser.parse('1,500,000 shopping', 'user123');
      expect(result.success, true);
      expect(result.expense!.amount, 1500000.0);
    });

    test('handles decimal amounts', () {
      final result = ExpenseParser.parse('1.5m groceries', 'user123');
      expect(result.success, true);
      expect(result.expense!.amount, 1500000.0);
    });

    test('creates valid expense ID', () {
      final result = ExpenseParser.parse('50k coffee', 'user123');
      expect(result.expense!.id, isNotEmpty);
    });

    test('sets correct user ID', () {
      final result = ExpenseParser.parse('50k coffee', 'testuser');
      expect(result.expense!.userId, 'testuser');
    });

    test('sets current timestamp', () {
      final before = DateTime.now();
      final result = ExpenseParser.parse('50k coffee', 'user123');
      final after = DateTime.now();

      expect(
        result.expense!.date.isAfter(before.subtract(Duration(seconds: 1))),
        true,
      );
      expect(result.expense!.date.isBefore(after.add(Duration(seconds: 1))), true);
    });

    test('preserves raw input', () {
      final input = '50k coffee with milk';
      final result = ExpenseParser.parse(input, 'user123');
      expect(result.expense!.rawInput, input);
    });
  });
}

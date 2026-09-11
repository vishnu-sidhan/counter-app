import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/services/csv_import_service.dart';
import 'package:counter_app/theme/category_colors.dart';

void main() {
  group('CsvImportService - Menu Items', () {
    test('parses standard 3-column CSV with headers', () {
      const csv = '''name,price,category
Masala Chai,20,Beverages
Veg Samosa,25,Snacks
Paneer Roll,80.50,Fast Food''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.skippedRowsCount, 0);
      expect(result.items[0].name, 'Masala Chai');
      expect(result.items[0].price, 20.0);
      expect(result.items[0].category, 'Beverages');

      expect(result.items[1].name, 'Veg Samosa');
      expect(result.items[1].price, 25.0);
      expect(result.items[1].category, 'Snacks');

      expect(result.items[2].name, 'Paneer Roll');
      expect(result.items[2].price, 80.50);
      expect(result.items[2].category, 'Fast Food');
    });

    test('handles RFC 4180 quotes and commas inside fields', () {
      const csv = '''"name","price","category"
"Chai, Special Masala",30,"Hot Drinks, Tea"
"Double ""Deluxe"" Burger",150,Fast Food''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 2);
      expect(result.items[0].name, 'Chai, Special Masala');
      expect(result.items[0].price, 30.0);
      expect(result.items[0].category, 'Hot Drinks, Tea');

      expect(result.items[1].name, 'Double "Deluxe" Burger');
      expect(result.items[1].price, 150.0);
    });

    test('cleans currency symbols and defaults category to General', () {
      const csv = '''item,rate
Coffee,₹ 40
Tea,\$2.50
Water Bottle,20''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.items[0].name, 'Coffee');
      expect(result.items[0].price, 40.0);
      expect(result.items[0].category, 'General');

      expect(result.items[1].price, 2.50);
      expect(result.items[2].price, 20.0);
    });

    test('skips rows with missing names or non-positive prices', () {
      const csv = '''name,price,category
Valid Item,50,Snacks
,40,Snacks
Invalid Price,abc,Snacks
Free Item,0,Promos
Negative Item,-10,Snacks''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);

      expect(result.items.length, 1);
      expect(result.items[0].name, 'Valid Item');
      expect(result.skippedRowsCount, 4);
      expect(result.warnings.length, 4);
    });

    test('handles empty CSV input gracefully', () {
      final result = CsvImportService.parseMenuItemsFromCsv('   \n  \n');
      expect(result.items, isEmpty);
      expect(result.hasItems, isFalse);
      expect(result.warnings, isNotEmpty);
    });

    test('parses menu CSV with explicit color column', () {
      const csv = '''name,price,category,color
Masala Chai,20,Beverages,#EA580C
Veg Samosa,25,Snacks,0xFF059669
Chocolate Donut,60,Dessert,crimson''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);
      expect(result.items[0].colorHex, 0xFFEA580C);
      expect(result.items[1].colorHex, 0xFF059669);
      expect(result.items[2].colorHex, 0xFFDC2626);
    });

    test('assigns random category color when color is not defined and shares color across category', () {
      const csv = '''name,price,category
Filter Coffee,30,Beverages
Masala Chai,20,Beverages
Veg Puff,35,Snacks''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);
      // Colors are assigned
      expect(result.items[0].colorHex, isNotNull);
      expect(result.items[1].colorHex, isNotNull);
      expect(result.items[2].colorHex, isNotNull);

      // Same category shares the assigned category color
      expect(result.items[0].colorHex, equals(result.items[1].colorHex));

      // Different category can have a different color
      expect(result.items[0].category, 'Beverages');
      expect(result.items[2].category, 'Snacks');
    });

    test('guarantees unique and distinct colors for all imported categories', () {
      const csv = '''name,price,category
Tea,10,Hot Drinks
Coffee,20,Cold Drinks
Samosa,15,Snacks
Burger,50,Fast Food
Cake,40,Desserts
Biryani,100,Meals
Combo,120,Combos''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 7);

      final categoryColors = <String, int>{};
      for (final item in result.items) {
        categoryColors[item.category] = item.colorHex!;
      }

      // 7 categories must produce 7 strictly unique colors
      expect(categoryColors.values.toSet().length, equals(7));

      // Check that all assigned colors have significant perceptual distance (no two look the same)
      final colorsList = categoryColors.values.toList();
      for (int i = 0; i < colorsList.length; i++) {
        for (int j = i + 1; j < colorsList.length; j++) {
          final dist = CategoryColorHelper.colorDistance(colorsList[i], colorsList[j]);
          expect(dist, greaterThanOrEqualTo(70.0),
              reason: 'Colors ${colorsList[i]} and ${colorsList[j]} must be visually distinct');
        }
      }
    });

    test('parses is_addon and linked_category columns for category-linked add-ons', () {
      const csv = '''name,price,category,is_addon,linked_category
Veg Burger,80,Fast Food,false,
Extra Cheese,25,Addons,true,Fast Food
Ginger,5,Extras,true,Beverages''';

      final result = CsvImportService.parseMenuItemsFromCsv(csv);
      expect(result.items.length, 3);

      final burger = result.items[0];
      expect(burger.name, 'Veg Burger');
      expect(burger.isAddon, isFalse);
      expect(burger.linkedCategory, isNull);

      final cheese = result.items[1];
      expect(cheese.name, 'Extra Cheese');
      expect(cheese.isAddon, isTrue);
      expect(cheese.linkedCategory, 'Fast Food');
      expect(cheese.isApplicableToCategory('Fast Food'), isTrue);
      expect(cheese.isApplicableToCategory('Beverages'), isFalse);

      final ginger = result.items[2];
      expect(ginger.name, 'Ginger');
      expect(ginger.isAddon, isTrue);
      expect(ginger.linkedCategory, 'Beverages');
      expect(ginger.isApplicableToCategory('Beverages'), isTrue);
      expect(ginger.isApplicableToCategory('Fast Food'), isFalse);
    });
  });

  group('CsvImportService - Counters', () {
    test('parses counter CSV with standard headers', () {
      const csv = '''title,count,step,target,allowNegative,colorHex
Glasses of Water,2,1,8,false,0xFF0284C7
Workout Reps,10,5,100,false,#059669
Negative Tracker,0,1,,true,0xFFDC2626''';

      final result = CsvImportService.parseCountersFromCsv(csv);

      expect(result.items.length, 3);
      expect(result.items[0].title, 'Glasses of Water');
      expect(result.items[0].count, 2);
      expect(result.items[0].step, 1);
      expect(result.items[0].target, 8);
      expect(result.items[0].allowNegative, isFalse);
      expect(result.items[0].colorHex, 0xFF0284C7);

      expect(result.items[1].title, 'Workout Reps');
      expect(result.items[1].count, 10);
      expect(result.items[1].step, 5);
      expect(result.items[1].target, 100);
      expect(result.items[1].colorHex, 0xFF059669);

      expect(result.items[2].title, 'Negative Tracker');
      expect(result.items[2].target, isNull);
      expect(result.items[2].allowNegative, isTrue);
    });

    test('skips counters without title', () {
      const csv = '''title,count,step
Daily Pushups,0,10
,5,1''';

      final result = CsvImportService.parseCountersFromCsv(csv);

      expect(result.items.length, 1);
      expect(result.items[0].title, 'Daily Pushups');
      expect(result.skippedRowsCount, 1);
    });
  });
}

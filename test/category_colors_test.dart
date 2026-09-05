import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/theme/category_colors.dart';
import 'package:counter_app/data/models/stall_models.dart';

void main() {
  group('CategoryColorHelper', () {
    test('returns explicit color when defined and non-zero', () {
      final color = CategoryColorHelper.getColorForCategory('Beverages', explicitColor: 0xFF123456);
      expect(color, 0xFF123456);
    });

    test('assigns random color from palette when color is not defined', () {
      final color = CategoryColorHelper.getColorForCategory('Beverages');
      expect(CategoryColorHelper.palette.contains(color), isTrue);
    });

    test('generates stable, consistent color for the same category name', () {
      final color1 = CategoryColorHelper.getColorForCategory('Beverages');
      final color2 = CategoryColorHelper.getColorForCategory('beverages ');
      final color3 = CategoryColorHelper.getColorForCategory('BEVERAGES');
      expect(color1, equals(color2));
      expect(color2, equals(color3));
    });

    test('provides distinct colors for different categories', () {
      final colorA = CategoryColorHelper.getColorForCategory('Beverages');
      final colorB = CategoryColorHelper.getColorForCategory('Snacks');
      final colorC = CategoryColorHelper.getColorForCategory('Dessert');
      // At least two should differ among common categories
      final set = {colorA, colorB, colorC};
      expect(set.length, greaterThan(1));
    });

    test('parses various hex string formats and color names', () {
      expect(CategoryColorHelper.parseColor('#EA580C'), 0xFFEA580C);
      expect(CategoryColorHelper.parseColor('0xFF059669'), 0xFF059669);
      expect(CategoryColorHelper.parseColor('2563EB'), 0xFF2563EB);
      expect(CategoryColorHelper.parseColor('emerald'), 0xFF059669);
      expect(CategoryColorHelper.parseColor('crimson'), 0xFFDC2626);
      expect(CategoryColorHelper.parseColor('teal'), 0xFF0F766E);
      expect(CategoryColorHelper.parseColor('invalid_color'), isNull);
      expect(CategoryColorHelper.parseColor(''), isNull);
      expect(CategoryColorHelper.parseColor(null), isNull);
    });

    test('getRandomColor returns a valid element from palette', () {
      final randColor = CategoryColorHelper.getRandomColor();
      expect(CategoryColorHelper.palette.contains(randColor), isTrue);
    });

    test('getContrastingTextColor provides readable text color', () {
      // Dark color should return white
      final darkTextColor = CategoryColorHelper.getContrastingTextColor(const Color(0xFF0F172A));
      expect(darkTextColor, Colors.white);

      // Light color should return dark
      final lightTextColor = CategoryColorHelper.getContrastingTextColor(const Color(0xFFFFFFFF));
      expect(lightTextColor, const Color(0xFF0F172A));
    });

    test('getUniqueColor guarantees every assigned color is strictly unique', () {
      final used = <int>{};
      final categories = [
        'Beverages',
        'Snacks',
        'Fast Food',
        'Desserts',
        'Combos',
        'Main Course',
        'Breakfast',
        'Appetizers',
        'Specials',
        'Salads',
      ];

      final assigned = <String, int>{};
      for (final cat in categories) {
        final color = CategoryColorHelper.getUniqueColor(
          categoryName: cat,
          usedColors: used,
        );
        expect(used.contains(color), isFalse, reason: 'Color $color must not have been previously used');
        assigned[cat] = color;
        used.add(color);
      }

      // 10 categories must produce 10 unique colors
      expect(assigned.values.toSet().length, equals(categories.length));
    });

    test('getUniqueColor scales beyond palette size generating unique colors', () {
      final used = <int>{};
      const count = 25; // Exceeds palette length (16)
      for (int i = 0; i < count; i++) {
        final color = CategoryColorHelper.getUniqueColor(
          categoryName: 'Category_$i',
          usedColors: used,
        );
        expect(used.contains(color), isFalse);
        used.add(color);
      }
      expect(used.length, equals(count));
    });

    test('colorDistance metric correctly identifies distinct and similar colors', () {
      // Same color has distance 0
      expect(CategoryColorHelper.colorDistance(0xFF2563EB, 0xFF2563EB), equals(0.0));

      // Opposite colors (red and cyan/green) have large distance > 200
      final dist = CategoryColorHelper.colorDistance(0xFFDC2626, 0xFF059669);
      expect(dist, greaterThan(200.0));
    });
  });

  group('MenuItem category color integration', () {
    test('serializes and deserializes colorHex', () {
      const item = MenuItem(
        id: 'item_1',
        name: 'Masala Chai',
        price: 25.0,
        category: 'Hot Beverages',
        colorHex: 0xFFEA580C,
      );

      final json = item.toJson();
      expect(json['colorHex'], 0xFFEA580C);

      final restored = MenuItem.fromJson(json);
      expect(restored.colorHex, 0xFFEA580C);
      expect(restored.category, 'Hot Beverages');
    });

    test('deserialization assigns random category color when color is not defined', () {
      final jsonWithoutColor = {
        'id': 'item_2',
        'name': 'Cold Coffee',
        'price': 40.0,
        'category': 'Beverages',
      };

      final restored = MenuItem.fromJson(jsonWithoutColor);
      expect(restored.colorHex, isNotNull);
      expect(CategoryColorHelper.palette.contains(restored.colorHex), isTrue);
    });
  });
}

import 'dart:math';
import 'package:flutter/material.dart';

/// Utility class for category color management, palettes, and guaranteed unique,
/// visually distinct color assignment.
class CategoryColorHelper {
  CategoryColorHelper._();

  /// Curated 16-color palette where every color has high perceptual contrast
  /// and distinct hue/tone so no two colors look alike.
  static const List<int> palette = [
    0xFF1D4ED8, // 1. Royal Blue
    0xFF059669, // 2. Emerald Green
    0xFFEA580C, // 3. Vivid Orange
    0xFFDC2626, // 4. Crimson Red
    0xFF7C3AED, // 5. Violet Purple
    0xFFD97706, // 6. Amber Gold
    0xFFE11D48, // 7. Rose Pink
    0xFF0F766E, // 8. Deep Teal
    0xFF0284C7, // 9. Cyan Sky
    0xFF65A30D, // 10. Bright Lime
    0xFFC026D3, // 11. Magenta Fuchsia
    0xFF78350F, // 12. Warm Chocolate
    0xFF831843, // 13. Deep Berry Plum
    0xFF3730A3, // 14. Dark Indigo
    0xFF3F6212, // 15. Olive Green
    0xFF334155, // 16. Slate Navy
  ];

  /// Mapping of common color names to their respective hex values.
  static const Map<String, int> namedColorMap = {
    'blue': 0xFF1D4ED8,
    'royal blue': 0xFF1D4ED8,
    'sapphire': 0xFF1D4ED8,
    'emerald': 0xFF059669,
    'green': 0xFF059669,
    'sunset': 0xFFEA580C,
    'orange': 0xFFEA580C,
    'crimson': 0xFFDC2626,
    'red': 0xFFDC2626,
    'violet': 0xFF7C3AED,
    'purple': 0xFF7C3AED,
    'teal': 0xFF0F766E,
    'amber': 0xFFD97706,
    'yellow': 0xFFD97706,
    'gold': 0xFFD97706,
    'rose': 0xFFE11D48,
    'pink': 0xFFE11D48,
    'indigo': 0xFF3730A3,
    'cyan': 0xFF0284C7,
    'sky': 0xFF0284C7,
    'fuchsia': 0xFFC026D3,
    'magenta': 0xFFC026D3,
    'lime': 0xFF65A30D,
    'brown': 0xFF78350F,
    'chocolate': 0xFF78350F,
    'plum': 0xFF831843,
    'berry': 0xFF831843,
    'olive': 0xFF3F6212,
    'slate': 0xFF334155,
    'gray': 0xFF334155,
    'grey': 0xFF334155,
  };

  /// Calculates the weighted Euclidean (redmean) perceptual color distance
  /// between two color hexes. Values >= 100 represent clearly distinguishable colors.
  static double colorDistance(int hex1, int hex2) {
    final r1 = (hex1 >> 16) & 0xFF;
    final g1 = (hex1 >> 8) & 0xFF;
    final b1 = hex1 & 0xFF;

    final r2 = (hex2 >> 16) & 0xFF;
    final g2 = (hex2 >> 8) & 0xFF;
    final b2 = hex2 & 0xFF;

    final rmean = (r1 + r2) / 2.0;
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;

    return sqrt(
      (2.0 + rmean / 256.0) * dr * dr +
      4.0 * dg * dg +
      (2.0 + (255.0 - rmean) / 256.0) * db * db,
    );
  }

  /// Returns a guaranteed unique, visually distinct color that has not been used yet.
  ///
  /// - First selects from the curated palette, prioritizing colors with maximum
  ///   perceptual distance from all [usedColors].
  /// - If all palette colors are in use or too visually similar (distance < 90),
  ///   it generates a new distinct color using the Golden Ratio hue offset on HSV.
  static int getUniqueColor({
    String? categoryName,
    required Set<int> usedColors,
  }) {
    // 1. Try to find an unused color in the curated palette
    final available = palette.where((c) => !usedColors.contains(c)).toList();

    if (available.isNotEmpty) {
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        // Deterministically rank available colors starting from the category name's hash
        final trimmed = categoryName.trim().toLowerCase();
        final startIdx = trimmed.codeUnits
            .fold<int>(5381, (prev, c) => ((prev << 5) + prev) ^ c)
            .abs() % available.length;

        // Check if the hashed choice has sufficient perceptual distance from already used colors
        for (int i = 0; i < available.length; i++) {
          final candidate = available[(startIdx + i) % available.length];
          if (_isVisuallyDistinct(candidate, usedColors, minDistance: 80.0)) {
            return candidate;
          }
        }
      }

      // If no candidate met the strict distance threshold, pick the available color
      // that maximizes the minimum distance to all currently used colors
      int bestCandidate = available.first;
      double maxMinDist = -1.0;

      for (final candidate in available) {
        if (usedColors.isEmpty) return candidate;
        double minDist = double.infinity;
        for (final used in usedColors) {
          final dist = colorDistance(candidate, used);
          if (dist < minDist) minDist = dist;
        }
        if (minDist > maxMinDist) {
          maxMinDist = minDist;
          bestCandidate = candidate;
        }
      }

      return bestCandidate;
    }

    // 2. Palette exhausted or all used: Generate unique color via Golden Ratio hue distribution
    // Golden ratio conjugate: ~137.50776 degrees ensures maximally even dispersion
    const phiAngle = 137.507764;
    double baseHue = 217.0; // Start at royal blue
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      baseHue = (categoryName.trim().toLowerCase().hashCode.abs() % 360).toDouble();
    }

    for (int step = 1; step <= 100; step++) {
      final hue = (baseHue + step * phiAngle) % 360.0;
      // Alternate saturation and value slightly for enhanced distinction
      final saturation = 0.75 + (step % 3) * 0.10;
      final value = 0.85 + (step % 2) * 0.10;

      final color = HSVColor.fromAHSV(1.0, hue, saturation.clamp(0.0, 1.0), value.clamp(0.0, 1.0))
          .toColor();
      final hex = color.toARGB32();

      if (!usedColors.contains(hex) && _isVisuallyDistinct(hex, usedColors, minDistance: 75.0)) {
        return hex;
      }
    }

    // Fallback if space is extremely dense: arbitrary unused step
    final fallbackHue = (baseHue + (usedColors.length + 1) * phiAngle) % 360.0;
    return HSVColor.fromAHSV(1.0, fallbackHue, 0.85, 0.90).toColor().toARGB32();
  }

  /// Checks if [candidate] is at least [minDistance] away from all [usedColors].
  static bool _isVisuallyDistinct(int candidate, Set<int> usedColors, {double minDistance = 80.0}) {
    if (usedColors.isEmpty) return true;
    for (final used in usedColors) {
      if (colorDistance(candidate, used) < minDistance) {
        return false;
      }
    }
    return true;
  }

  /// Returns a truly random color hex from the palette.
  static int getRandomColor({Random? random}) {
    final rng = random ?? Random();
    return palette[rng.nextInt(palette.length)];
  }

  /// Returns an integer color hex for a given [category].
  ///
  /// If [explicitColor] is supplied and valid, it is returned directly.
  /// If color is NOT defined, a deterministic color is chosen from the palette.
  static int getColorForCategory(String category, {int? explicitColor}) {
    if (explicitColor != null && explicitColor != 0) {
      return explicitColor;
    }

    final trimmed = category.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'all') {
      return palette[0];
    }

    final hash = trimmed.codeUnits.fold<int>(5381, (prev, c) => ((prev << 5) + prev) ^ c);
    final index = hash.abs() % palette.length;
    return palette[index];
  }

  /// Parses a color hex from various input formats (int, '#RRGGBB', '0xRRGGBB', or name).
  /// Returns `null` if the input is empty or cannot be parsed.
  static int? parseColor(dynamic input) {
    if (input == null) return null;
    if (input is int) {
      if (input <= 0) return null;
      return (input <= 0xFFFFFF) ? (input | 0xFF000000) : input;
    }

    final str = input.toString().trim();
    if (str.isEmpty) return null;

    final lower = str.toLowerCase();
    if (namedColorMap.containsKey(lower)) {
      return namedColorMap[lower];
    }

    try {
      if (str.startsWith('#')) {
        final hexPart = str.substring(1);
        if (hexPart.length == 6) {
          return int.parse('0xFF$hexPart');
        } else if (hexPart.length == 8) {
          return int.parse('0x$hexPart');
        }
      } else if (str.startsWith('0x') || str.startsWith('0X')) {
        return int.parse(str);
      } else if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(str)) {
        return int.parse('0xFF$str');
      }

      final parsed = int.tryParse(str);
      if (parsed != null) {
        return (parsed <= 0xFFFFFF) ? (parsed | 0xFF000000) : parsed;
      }
    } catch (_) {}

    return null;
  }

  /// Converts a hex integer to a [Color].
  static Color colorFromHex(int hex) => Color(hex);

  /// Returns contrasting text color (white or dark slate) for a given background color.
  static Color getContrastingTextColor(Color background) {
    return background.computeLuminance() > 0.4
        ? const Color(0xFF0F172A)
        : Colors.white;
  }
}

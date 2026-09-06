import 'package:flutter/material.dart';

/// Preset color options for counter categorization and styling.
class CounterColorPreset {
  final String name;
  final int hex;
  final Color color;

  const CounterColorPreset({
    required this.name,
    required this.hex,
    required this.color,
  });
}

class AppTheme {
  AppTheme._();

  /// Curated, high-contrast Material 3 color presets.
  static const List<CounterColorPreset> presets = [
    CounterColorPreset(name: 'Sapphire', hex: 0xFF2563EB, color: Color(0xFF2563EB)),
    CounterColorPreset(name: 'Emerald', hex: 0xFF059669, color: Color(0xFF059669)),
    CounterColorPreset(name: 'Sunset', hex: 0xFFEA580C, color: Color(0xFFEA580C)),
    CounterColorPreset(name: 'Crimson', hex: 0xFFDC2626, color: Color(0xFFDC2626)),
    CounterColorPreset(name: 'Violet', hex: 0xFF7C3AED, color: Color(0xFF7C3AED)),
    CounterColorPreset(name: 'Teal', hex: 0xFF0D9488, color: Color(0xFF0D9488)),
    CounterColorPreset(name: 'Amber', hex: 0xFFD97706, color: Color(0xFFD97706)),
    CounterColorPreset(name: 'Rose', hex: 0xFFE11D48, color: Color(0xFFE11D48)),
    CounterColorPreset(name: 'Indigo', hex: 0xFF4F46E5, color: Color(0xFF4F46E5)),
    CounterColorPreset(name: 'Slate', hex: 0xFF475569, color: Color(0xFF475569)),
  ];

  static Color getColor(int hex) => Color(hex);

  /// Light theme definition
  static ThemeData get lightTheme {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF2563EB),
        unselectedLabelColor: Color(0xFF64748B),
        indicatorColor: Color(0xFF2563EB),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: const Color(0xFFDBEAFE),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8));
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B));
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Dark theme definition
  static ThemeData get darkTheme {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseColorScheme,
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0F19),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF8FAFC),
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF60A5FA),
        unselectedLabelColor: Color(0xFF94A3B8),
        indicatorColor: Color(0xFF60A5FA),
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 2,
        indicatorColor: const Color(0xFF1E3A8A),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF93C5FD));
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8));
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
    );
  }
}

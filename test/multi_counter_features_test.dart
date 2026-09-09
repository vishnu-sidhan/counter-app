import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/controllers/counter_controller.dart';
import 'package:counter_app/data/services/counter_storage_service.dart';
import 'package:counter_app/screens/home_screen.dart';

void main() {
  testWidgets('Multi-counter tagging, goal celebration, and filtering in HomeScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    // Seed counters with tags and target
    await controller.addCounter(
      title: 'Water Intake',
      initialCount: 8,
      target: 8,
      colorHex: 0xFF2563EB,
      tag: 'health',
    );
    await controller.addCounter(
      title: 'Reading Pages',
      initialCount: 15,
      target: 30,
      colorHex: 0xFF059669,
      tag: 'habits',
    );

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    // Verify both counters are shown initially
    expect(find.text('Water Intake'), findsOneWidget);
    expect(find.text('Reading Pages'), findsOneWidget);

    // Verify tag chips rendered on CounterCards
    expect(find.text('#health'), findsWidgets);
    expect(find.text('#habits'), findsWidgets);

    // Verify celebration cue rendered for completed target (Water Intake: 8/8)
    expect(find.textContaining('Goal Achieved (8)!'), findsOneWidget);

    // Verify tag filter chips in the top bar ('All', '#habits', '#health')
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '#health'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '#habits'), findsOneWidget);

    // Filter by #health
    await tester.tap(find.widgetWithText(FilterChip, '#health'));
    await tester.pumpAndSettle();

    expect(find.text('Water Intake'), findsOneWidget);
    expect(find.text('Reading Pages'), findsNothing);

    // Reset to 'All'
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Water Intake'), findsOneWidget);
    expect(find.text('Reading Pages'), findsOneWidget);
  });

  testWidgets('HomeScreen renders ReorderableListView when SortOption is custom', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    await controller.addCounter(title: 'Item A', colorHex: 0xFF2563EB);
    await controller.addCounter(title: 'Item B', colorHex: 0xFF059669);

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    // Default is recentlyUpdated -> ListView
    expect(find.byType(ListView), findsWidgets);
    expect(find.byType(ReorderableListView), findsNothing);

    // Switch to Custom sort
    controller.setSortOption(SortOption.custom);
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableListView), findsOneWidget);
  });
}

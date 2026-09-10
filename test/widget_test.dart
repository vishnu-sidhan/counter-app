import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/main.dart';
import 'package:counter_app/controllers/counter_controller.dart';
import 'package:counter_app/data/services/counter_storage_service.dart';

void main() {
  testWidgets('StallPosApp renders and allows creating a counter', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    await tester.pumpWidget(StallPosApp(controller: controller, initialIndex: 0));
    await tester.pumpAndSettle();

    // Verify empty state is displayed initially
    expect(find.text('No counters yet'), findsOneWidget);
    expect(find.text('New Counter'), findsOneWidget);

    // Tap the FAB to open the Add Counter sheet
    await tester.tap(find.text('New Counter'));
    await tester.pumpAndSettle();

    // Verify bottom sheet opened
    expect(find.text('Create New Counter'), findsOneWidget);
    expect(find.text('Counter Name *'), findsOneWidget);

    // Enter counter title
    await tester.enterText(find.byType(TextFormField).first, 'Coffee Cups');
    await tester.pumpAndSettle();

    // Tap submit button
    await tester.ensureVisible(find.text('Create Counter'));
    await tester.tap(find.text('Create Counter'));
    await tester.pumpAndSettle();

    // Verify counter card is now rendered in the list
    expect(find.text('Coffee Cups'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Tap increment (+)
    await tester.tap(find.byTooltip('Increment (+1)'));
    await tester.pumpAndSettle();

    // Verify counter incremented to 1
    expect(find.text('1'), findsOneWidget);

    // Tap Stall POS AppBar action
    await tester.tap(find.byTooltip('Stall POS'));
    await tester.pumpAndSettle();

    // Verify Stall POS screen is shown
    expect(find.text('⚡ StallPOS'), findsOneWidget);

    // Switch back to Counters screen via bottom navigation
    await tester.tap(find.byTooltip('Counters'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Counters'), findsOneWidget);
  });

  testWidgets('StallPosApp defaults to Stall POS tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    await tester.pumpWidget(StallPosApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('⚡ StallPOS'), findsOneWidget);
  });

  testWidgets('HomeScreen imports counters from CSV via AppBar action', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    await tester.pumpWidget(StallPosApp(controller: controller, initialIndex: 0));
    await tester.pumpAndSettle();

    // Verify CSV import action exists in AppBar
    expect(find.byTooltip('Import Counters from CSV'), findsOneWidget);

    // Tap CSV import
    await tester.tap(find.byTooltip('Import Counters from CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Import Counters from CSV'), findsOneWidget);

    // Switch to Paste Text tab
    await tester.tap(find.text('Paste Text'));
    await tester.pumpAndSettle();

    // Load sample
    await tester.tap(find.text('Load Sample'));
    await tester.pumpAndSettle();

    // Import items
    await tester.tap(find.text('Import 5 Items'));
    await tester.pumpAndSettle();

    // Verify counters were imported and rendered (sorted alphabetically)
    expect(controller.counters.length, 5);
    expect(find.text('Budget Delta'), findsOneWidget);
    expect(find.text('Daily Water Glasses'), findsOneWidget);
  });
}

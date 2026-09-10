import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/main.dart';
import 'package:counter_app/controllers/counter_controller.dart';
import 'package:counter_app/data/services/counter_storage_service.dart';

void main() {
  testWidgets('HistoryScreen renders and displays activity logs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = CounterStorageService(prefs: prefs);
    final controller = CounterController(storageService: storageService);
    await controller.init();

    // Create a counter and increment it to generate activity
    final counter = await controller.addCounter(
      title: 'Water Log',
      initialCount: 0,
      step: 1,
      colorHex: 0xFF2563EB,
    );
    await controller.increment(counter.id);

    await tester.pumpWidget(StallPosApp(controller: controller, initialIndex: 0));
    await tester.pumpAndSettle();

    // Verify history icon button is present in AppBar
    expect(find.byTooltip('Activity History'), findsOneWidget);

    // Tap history button to navigate to HistoryScreen
    await tester.tap(find.byTooltip('Activity History'));
    await tester.pumpAndSettle();

    // Verify HistoryScreen title
    expect(find.text('Activity History'), findsOneWidget);

    // Verify the log entry and filter chip are displayed
    expect(find.text('Water Log'), findsNWidgets(2));
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('Count: 1'), findsOneWidget);

    // Verify filter chips and action buttons
    expect(find.text('All Activity'), findsOneWidget);
    expect(find.byTooltip('Download CSV'), findsOneWidget);

    // Test Clear History dialog
    expect(find.byTooltip('Clear History'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear History'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Activity History?'), findsOneWidget);
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    // Verify empty state is now displayed
    expect(find.text('No activity recorded yet'), findsOneWidget);
  });
}

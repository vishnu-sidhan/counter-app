import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/data/models/stall_models.dart';
import 'package:counter_app/data/services/stall_storage_service.dart';
import 'package:counter_app/screens/order_history_screen.dart';
import 'package:counter_app/services/csv_export_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CsvExportService generates valid RFC 4180 CSV content for orders', () {
    final orders = [
      StallOrder(
        token: 1,
        itemsSummary: '1x "Special" Chai, 2x Samosa',
        total: 60.0,
        timestamp: DateTime(2026, 9, 5, 12, 0),
        isCompleted: true,
        completedAt: DateTime(2026, 9, 5, 12, 4),
      ),
    ];

    final csv = CsvExportService.generateOrdersCsv(orders);
    expect(csv, contains('Token,Timestamp,Date,Time,Status,Payment Status,Items Summary,Total Amount,Paid Amount,Balance Due,Completed At'));
    expect(csv, contains('#1'));
    expect(csv, contains('Completed'));
    expect(csv, contains('""Special"" Chai'));
    expect(csv, contains('60.00'));
  });

  testWidgets('OrderHistoryScreen renders metrics, filters, and displays order cards', (WidgetTester tester) async {
    final storageService = StallStorageService();
    final orders = [
      StallOrder(
        token: 1,
        itemsSummary: '1x Coffee',
        total: 50.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      StallOrder(
        token: 2,
        itemsSummary: '2x Tea',
        total: 40.0,
        timestamp: DateTime.now(),
        isCompleted: false,
      ),
    ];
    await storageService.saveOrders(orders);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderHistoryScreen(storageService: storageService),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Metrics Banner
    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('₹90'), findsOneWidget); // Total Revenue
    expect(find.text('2'), findsWidgets); // Orders count
    expect(find.text('₹45'), findsOneWidget); // Average value

    // Verify filter chips
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);

    // Filter to Completed
    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsNothing);

    // Filter to Pending
    await tester.tap(find.text('Pending (1)'));
    await tester.pumpAndSettle();

    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#1'), findsNothing);

    // Reset to All
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();

    // Tap Clear Completed button
    await tester.tap(find.byTooltip('Clear Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Clear Completed Orders?'), findsOneWidget);
    await tester.tap(find.text('Clear Completed'));
    await tester.pumpAndSettle();

    // Now only 1 order remains (the pending one)
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
  });

  testWidgets('OrderHistoryScreen search bar and date range chips filter orders correctly', (WidgetTester tester) async {
    final storageService = StallStorageService();
    final now = DateTime.now();
    final orders = [
      StallOrder(
        token: 101,
        itemsSummary: '2x Masala Dosa',
        total: 120.0,
        timestamp: now,
        customerName: 'Rahul',
        isCompleted: true,
      ),
      StallOrder(
        token: 102,
        itemsSummary: '1x Cold Coffee',
        total: 60.0,
        timestamp: now.subtract(const Duration(days: 3)),
        customerName: 'Sneha',
        isCompleted: false,
      ),
    ];

    await storageService.saveOrders(orders);

    await tester.pumpWidget(
      MaterialApp(
        home: OrderHistoryScreen(storageService: storageService),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#102'), findsOneWidget);

    // Search for Rahul
    await tester.enterText(find.byType(TextField), 'Rahul');
    await tester.pumpAndSettle();
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#102'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#102'), findsOneWidget);

    // Filter by Today
    await tester.ensureVisible(find.text('Today'));
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('#101'), findsOneWidget);
    expect(find.text('#102'), findsNothing);
  });
}


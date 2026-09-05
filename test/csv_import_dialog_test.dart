import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/stall_models.dart';
import 'package:counter_app/data/models/counter_model.dart';
import 'package:counter_app/widgets/csv_import_dialog.dart';

void main() {
  testWidgets('CsvImportDialog imports menu items from pasted text', (WidgetTester tester) async {
    List<MenuItem>? importedItems;
    bool? replaced;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CsvImportDialog.showMenuItemsDialog(
                  context,
                  existingCount: 2,
                  onImport: (items, replaceExisting) {
                    importedItems = items;
                    replaced = replaceExisting;
                  },
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Import POS Menu Items'), findsOneWidget);
    expect(find.text('Upload File'), findsOneWidget);
    expect(find.text('Paste Text'), findsOneWidget);

    // Switch to Paste Text tab
    await tester.tap(find.text('Paste Text'));
    await tester.pumpAndSettle();

    // Tap 'Load Sample'
    await tester.tap(find.text('Load Sample'));
    await tester.pumpAndSettle();

    // Verify preview badges
    expect(find.textContaining('items parsed'), findsOneWidget);

    // Select 'Replace All' in SegmentedButton
    await tester.tap(find.text('Replace All'));
    await tester.pumpAndSettle();

    // Tap Import button
    await tester.tap(find.text('Import 7 Items'));
    await tester.pumpAndSettle();

    // Verify callback was fired
    expect(importedItems, isNotNull);
    expect(importedItems!.length, 7);
    expect(importedItems![0].name, 'Masala Chai');
    expect(replaced, isTrue);

    // Dialog is dismissed
    expect(find.text('Import POS Menu Items'), findsNothing);
  });

  testWidgets('CsvImportDialog imports counters from pasted text', (WidgetTester tester) async {
    List<CounterModel>? importedCounters;
    bool? replaced;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CsvImportDialog.showCountersDialog(
                  context,
                  existingCount: 0,
                  onImport: (items, replaceExisting) {
                    importedCounters = items;
                    replaced = replaceExisting;
                  },
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Import Counters from CSV'), findsOneWidget);

    // Switch to Paste Text tab
    await tester.tap(find.text('Paste Text'));
    await tester.pumpAndSettle();

    // Tap 'Load Sample'
    await tester.tap(find.text('Load Sample'));
    await tester.pumpAndSettle();

    // Tap Import button
    await tester.tap(find.text('Import 5 Items'));
    await tester.pumpAndSettle();

    expect(importedCounters, isNotNull);
    expect(importedCounters!.length, 5);
    expect(importedCounters![0].title, 'Daily Water Glasses');
    expect(replaced, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/counter_log_entry.dart';
import 'package:counter_app/services/csv_export_service.dart';

void main() {
  group('CsvExportService', () {
    final testDate = DateTime(2026, 6, 10, 15, 45, 30);

    test('generates valid RFC 4180 CSV content with escaping', () {
      final logs = [
        CounterLogEntry(
          id: 'log-1',
          counterId: 'counter-1',
          counterTitle: 'Pushups & Pullups, Day 1',
          counterColorHex: 0xFF2563EB,
          actionType: CounterActionType.increment,
          changeAmount: 5,
          resultingCount: 25,
          timestamp: testDate,
        ),
        CounterLogEntry(
          id: 'log-2',
          counterId: 'counter-2',
          counterTitle: 'Read "Atomic Habits"',
          counterColorHex: 0xFF059669,
          actionType: CounterActionType.reset,
          changeAmount: -20,
          resultingCount: 0,
          timestamp: testDate.add(const Duration(minutes: 10)),
        ),
      ];

      final csv = CsvExportService.generateCsv(logs);

      // Verify Header
      expect(
        csv.contains('ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count'),
        isTrue,
      );

      // Verify escaped quotes and commas in titles
      expect(csv.contains('"Pushups & Pullups, Day 1"'), isTrue);
      expect(csv.contains('"Read ""Atomic Habits"""'), isTrue);

      // Verify actions and changes
      expect(csv.contains('Increment,+5,25'), isTrue);
      expect(csv.contains('Reset,-20,0'), isTrue);
    });

    test('handles empty logs list gracefully', () {
      final csv = CsvExportService.generateCsv([]);
      expect(
        csv.trim(),
        'ID,Timestamp,Date,Time,Counter Title,Action,Change,Resulting Count',
      );
    });
  });
}

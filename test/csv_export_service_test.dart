import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/counter_log_entry.dart';
import 'package:counter_app/data/models/stall_models.dart';
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

    test('generates orders CSV with payment audit fields', () {
      final orders = [
        StallOrder(
          token: 1,
          itemsSummary: '2x Masala Chai',
          total: 40.0,
          timestamp: testDate,
          isCompleted: false,
          isPaid: false,
          paidAmount: 0.0,
          customerName: 'Aarav',
        ),
        StallOrder(
          token: 2,
          itemsSummary: '1x Veg Samosa, 1x Chai',
          total: 50.0,
          timestamp: testDate.add(const Duration(minutes: 5)),
          isCompleted: true,
          completedAt: testDate.add(const Duration(minutes: 10)),
          isPaid: true,
          paidAmount: 50.0,
          paymentMethod: 'Cash',
          customerName: 'Priya',
        ),
        StallOrder(
          token: 3,
          itemsSummary: '2x Paneer Roll',
          total: 140.0,
          timestamp: testDate.add(const Duration(minutes: 8)),
          isCompleted: false,
          isPaid: false,
          paidAmount: 70.0,
          paymentMethod: 'UPI',
          customerName: 'Rahul',
        ),
      ];

      final csv = CsvExportService.generateOrdersCsv(orders);

      expect(
        csv.contains('Token,Timestamp,Date,Time,Status,Payment Status,Items Summary,Total Amount,Paid Amount,Balance Due,Completed At,Customer Name,Payment Method'),
        isTrue,
      );
      // Check Order 1: Unpaid
      expect(csv.contains('#1,'), isTrue);
      expect(csv.contains(',Pending,Unpaid,"2x Masala Chai",40.00,0.00,40.00,'), isTrue);
      // Check Order 2: Paid
      expect(csv.contains('#2,'), isTrue);
      expect(csv.contains(',Completed,Paid,"1x Veg Samosa, 1x Chai",50.00,50.00,0.00,'), isTrue);
      // Check Order 3: Partial
      expect(csv.contains('#3,'), isTrue);
      expect(csv.contains(',Pending,Partial,"2x Paneer Roll",140.00,70.00,70.00,'), isTrue);
    });
  });
}

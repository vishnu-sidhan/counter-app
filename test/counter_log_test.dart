import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/counter_log_entry.dart';

void main() {
  group('CounterLogEntry', () {
    final testDate = DateTime(2026, 3, 15, 14, 30, 45);

    test('serializes to and from JSON accurately', () {
      final entry = CounterLogEntry(
        id: 'log-123',
        counterId: 'counter-abc',
        counterTitle: 'Glasses of Water',
        counterColorHex: 0xFF059669,
        actionType: CounterActionType.increment,
        changeAmount: 1,
        resultingCount: 5,
        timestamp: testDate,
      );

      final json = entry.toJson();
      final restored = CounterLogEntry.fromJson(json);

      expect(restored.id, 'log-123');
      expect(restored.counterId, 'counter-abc');
      expect(restored.counterTitle, 'Glasses of Water');
      expect(restored.counterColorHex, 0xFF059669);
      expect(restored.actionType, CounterActionType.increment);
      expect(restored.changeAmount, 1);
      expect(restored.resultingCount, 5);
      expect(restored.timestamp, testDate);
    });

    test('handles fallback defaults on fromJson', () {
      final restored = CounterLogEntry.fromJson({});

      expect(restored.counterTitle, 'Counter');
      expect(restored.actionType, CounterActionType.increment);
      expect(restored.changeAmount, 1);
      expect(restored.resultingCount, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/counter_model.dart';

void main() {
  group('CounterModel', () {
    final testDate = DateTime(2026, 1, 1, 12, 0);

    test('creates with default parameters', () {
      final counter = CounterModel(
        id: 'test-1',
        title: 'Water',
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(counter.id, 'test-1');
      expect(counter.title, 'Water');
      expect(counter.count, 0);
      expect(counter.step, 1);
      expect(counter.colorHex, 0xFF2563EB);
      expect(counter.target, isNull);
      expect(counter.allowNegative, isFalse);
      expect(counter.progress, isNull);
      expect(counter.isTargetReached, isFalse);
    });

    test('computes target progress correctly', () {
      final counter = CounterModel(
        id: 'test-2',
        title: 'Pushups',
        count: 5,
        target: 10,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(counter.progress, 0.5);
      expect(counter.progressPercentage, 50);
      expect(counter.isTargetReached, isFalse);

      final reached = counter.copyWith(count: 10);
      expect(reached.progress, 1.0);
      expect(reached.isTargetReached, isTrue);

      final exceeded = counter.copyWith(count: 15);
      expect(exceeded.progress, 1.0); // Clamped at 1.0
      expect(exceeded.progressPercentage, 150);
      expect(exceeded.isTargetReached, isTrue);
    });

    test('serializes to and from JSON accurately', () {
      final original = CounterModel(
        id: 'test-json',
        title: 'Daily Reading',
        count: 42,
        step: 5,
        colorHex: 0xFF059669,
        target: 50,
        allowNegative: true,
        createdAt: testDate,
        updatedAt: testDate,
      );

      final json = original.toJson();
      final restored = CounterModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.count, original.count);
      expect(restored.step, original.step);
      expect(restored.colorHex, original.colorHex);
      expect(restored.target, original.target);
      expect(restored.allowNegative, original.allowNegative);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('handles null or missing fields during fromJson gracefully', () {
      final restored = CounterModel.fromJson({});

      expect(restored.title, 'Untitled Counter');
      expect(restored.count, 0);
      expect(restored.step, 1);
      expect(restored.allowNegative, isFalse);
    });
  });
}

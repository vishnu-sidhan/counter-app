import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/controllers/counter_controller.dart';
import 'package:counter_app/data/models/counter_log_entry.dart';
import 'package:counter_app/data/services/counter_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CounterStorageService storageService;
  late CounterController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = CounterStorageService(prefs: prefs);
    controller = CounterController(storageService: storageService);
    await controller.init();
  });

  group('CounterController', () {
    test('initializes empty', () {
      expect(controller.totalCountersCount, 0);
      expect(controller.totalCountSum, 0);
      expect(controller.filteredCounters, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('adds counter correctly and persists', () async {
      final counter = await controller.addCounter(
        title: 'Water Glasses',
        initialCount: 2,
        step: 1,
        colorHex: 0xFF2563EB,
        target: 8,
      );

      expect(controller.totalCountersCount, 1);
      expect(controller.totalCountSum, 2);
      expect(controller.filteredCounters.first.id, counter.id);
      expect(controller.filteredCounters.first.title, 'Water Glasses');
      expect(controller.filteredCounters.first.target, 8);

      // Verify persistence by loading in a new storage service
      final stored = await storageService.loadCounters();
      expect(stored.length, 1);
      expect(stored.first.title, 'Water Glasses');
    });

    test('increments counter by step', () async {
      final counter = await controller.addCounter(
        title: 'Pushups',
        initialCount: 10,
        step: 5,
        colorHex: 0xFF2563EB,
      );

      await controller.increment(counter.id);
      expect(controller.filteredCounters.first.count, 15);

      await controller.increment(counter.id);
      expect(controller.filteredCounters.first.count, 20);
    });

    test('decrements counter respecting allowNegative bounds', () async {
      final counterBounded = await controller.addCounter(
        title: 'Bounded',
        initialCount: 3,
        step: 2,
        colorHex: 0xFF2563EB,
        allowNegative: false,
      );

      await controller.decrement(counterBounded.id);
      expect(controller.filteredCounters.first.count, 1);

      // Next decrement should bound at 0
      await controller.decrement(counterBounded.id);
      expect(controller.filteredCounters.first.count, 0);

      // Once at 0, remains 0
      await controller.decrement(counterBounded.id);
      expect(controller.filteredCounters.first.count, 0);

      // Now test negative allowed
      final counterUnbounded = await controller.addCounter(
        title: 'Unbounded',
        initialCount: 1,
        step: 2,
        colorHex: 0xFF2563EB,
        allowNegative: true,
      );

      await controller.decrement(counterUnbounded.id);
      expect(controller.filteredCounters.firstWhere((c) => c.id == counterUnbounded.id).count, -1);
    });

    test('resets counter to 0', () async {
      final counter = await controller.addCounter(
        title: 'Reps',
        initialCount: 50,
        colorHex: 0xFF2563EB,
      );

      await controller.reset(counter.id);
      expect(controller.filteredCounters.first.count, 0);
    });

    test('updates counter properties', () async {
      final counter = await controller.addCounter(
        title: 'Old Title',
        initialCount: 10,
        step: 1,
        colorHex: 0xFF2563EB,
      );

      final success = await controller.updateCounter(
        id: counter.id,
        title: 'New Title',
        count: 20,
        step: 5,
        colorHex: 0xFF059669,
        target: 100,
        allowNegative: false,
      );

      expect(success, isTrue);
      final updated = controller.filteredCounters.first;
      expect(updated.title, 'New Title');
      expect(updated.count, 20);
      expect(updated.step, 5);
      expect(updated.colorHex, 0xFF059669);
      expect(updated.target, 100);
    });

    test('deletes and restores counter (undo)', () async {
      final counter = await controller.addCounter(
        title: 'Temporary',
        initialCount: 5,
        colorHex: 0xFF2563EB,
      );

      final (deleted, index) = controller.deleteCounter(counter.id);
      expect(deleted, isNotNull);
      expect(deleted!.id, counter.id);
      expect(index, 0);
      expect(controller.totalCountersCount, 0);

      controller.restoreCounter(deleted, index);
      expect(controller.totalCountersCount, 1);
      expect(controller.filteredCounters.first.id, counter.id);
    });

    test('filters counters by search query', () async {
      await controller.addCounter(title: 'Morning Yoga', colorHex: 0xFF2563EB);
      await controller.addCounter(title: 'Evening Walk', colorHex: 0xFF2563EB);
      await controller.addCounter(title: 'Water Hydration', colorHex: 0xFF2563EB);

      controller.setSearchQuery('walk');
      expect(controller.filteredCounters.length, 1);
      expect(controller.filteredCounters.first.title, 'Evening Walk');

      controller.setSearchQuery('ing');
      expect(controller.filteredCounters.length, 2);

      controller.setSearchQuery('');
      expect(controller.filteredCounters.length, 3);
    });

    test('sorts counters by criteria with alphabetical as default', () async {
      expect(controller.sortOption, SortOption.alphabetical);

      await controller.addCounter(
        title: 'Zebra',
        initialCount: 10,
        colorHex: 0xFF2563EB,
      );
      await controller.addCounter(
        title: 'Alpha',
        initialCount: 50,
        colorHex: 0xFF2563EB,
      );
      await controller.addCounter(
        title: 'Beta',
        initialCount: 30,
        colorHex: 0xFF2563EB,
      );

      // Default is Alphabetical
      expect(controller.filteredCounters.map((c) => c.title).toList(), ['Alpha', 'Beta', 'Zebra']);

      // Highest Count
      controller.setSortOption(SortOption.highestCount);
      expect(controller.filteredCounters.map((c) => c.count).toList(), [50, 30, 10]);

      // Recently Updated
      controller.setSortOption(SortOption.recentlyUpdated);
      expect(controller.filteredCounters.map((c) => c.title).toList(), ['Beta', 'Alpha', 'Zebra']);

      // Back to Alphabetical
      controller.setSortOption(SortOption.alphabetical);
      expect(controller.filteredCounters.map((c) => c.title).toList(), ['Alpha', 'Beta', 'Zebra']);
    });

    test('records activity logs on increment, decrement, and reset', () async {
      final counter = await controller.addCounter(
        title: 'Habit',
        initialCount: 5,
        step: 2,
        colorHex: 0xFF059669,
      );

      expect(controller.logs, isEmpty);

      // Increment
      await controller.increment(counter.id);
      expect(controller.logs.length, 1);
      final incLog = controller.logs.first;
      expect(incLog.counterId, counter.id);
      expect(incLog.actionType, CounterActionType.increment);
      expect(incLog.changeAmount, 2);
      expect(incLog.resultingCount, 7);

      // Decrement
      await controller.decrement(counter.id);
      expect(controller.logs.length, 2);
      final decLog = controller.logs.first;
      expect(decLog.actionType, CounterActionType.decrement);
      expect(decLog.changeAmount, -2);
      expect(decLog.resultingCount, 5);

      // Reset
      await controller.reset(counter.id);
      expect(controller.logs.length, 3);
      final resetLog = controller.logs.first;
      expect(resetLog.actionType, CounterActionType.reset);
      expect(resetLog.resultingCount, 0);

      // Verify log filtering by counter
      controller.filterLogsByCounter(counter.id);
      expect(controller.filteredLogs.length, 3);

      controller.filterLogsByCounter('non-existent-id');
      expect(controller.filteredLogs, isEmpty);

      controller.filterLogsByCounter(null);
      expect(controller.filteredLogs.length, 3);

      // Verify clear all logs
      await controller.clearAllLogs();
      expect(controller.logs, isEmpty);
    });
  });
}

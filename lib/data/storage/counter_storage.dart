import '../models/counter_model.dart';
import '../models/counter_log_entry.dart';

/// Abstract storage contract for Multi-Counter items and activity logs.
abstract class CounterStorage {
  static const int maxStoredLogs = 1000;

  /// Loads all saved counters.
  Future<List<CounterModel>> loadCounters();

  /// Persists the list of counters.
  Future<bool> saveCounters(List<CounterModel> counters);

  /// Loads all saved activity logs.
  Future<List<CounterLogEntry>> loadLogs();

  /// Persists the list of activity logs.
  Future<bool> saveLogs(List<CounterLogEntry> logs);

  /// Clears saved activity logs.
  Future<bool> clearLogs();

  /// Clears all saved counters and logs.
  Future<bool> clearAll();
}

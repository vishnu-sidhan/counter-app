import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/counter_model.dart';
import '../models/counter_log_entry.dart';
import '../storage/counter_storage.dart';

/// Local service responsible for persistence using SharedPreferences and JSON encoding.
class CounterStorageService implements CounterStorage {
  static const String _storageKey = 'multi_counter_items_v1';
  static const String _logsStorageKey = 'multi_counter_logs_v1';
  static const int maxStoredLogs = 1000;

  final SharedPreferences? _prefsInstance;

  /// Allows passing an optional SharedPreferences instance for dependency injection & testing.
  CounterStorageService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  /// Loads all saved counters from local storage.
  /// Returns an empty list if no data exists or on error.
  @override
  Future<List<CounterModel>> loadCounters() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.trim().isEmpty) {
        return <CounterModel>[];
      }

      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .map((item) {
              if (item is Map<String, dynamic>) {
                return CounterModel.fromJson(item);
              } else if (item is Map) {
                return CounterModel.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<CounterModel>()
            .toList();
      }
      return <CounterModel>[];
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to load counters - $e\n$stackTrace');
      return <CounterModel>[];
    }
  }

  /// Persists the list of counters as a JSON array string.
  @override
  Future<bool> saveCounters(List<CounterModel> counters) async {
    try {
      final prefs = await _getPrefs();
      final listMap = counters.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(listMap);
      return await prefs.setString(_storageKey, jsonString);
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to save counters - $e\n$stackTrace');
      return false;
    }
  }

  /// Loads all saved activity logs from local storage.
  @override
  Future<List<CounterLogEntry>> loadLogs() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(_logsStorageKey);

      if (jsonString == null || jsonString.trim().isEmpty) {
        return <CounterLogEntry>[];
      }

      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .map((item) {
              if (item is Map<String, dynamic>) {
                return CounterLogEntry.fromJson(item);
              } else if (item is Map) {
                return CounterLogEntry.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<CounterLogEntry>()
            .toList();
      }
      return <CounterLogEntry>[];
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to load logs - $e\n$stackTrace');
      return <CounterLogEntry>[];
    }
  }

  /// Persists the list of activity logs, retaining up to maxStoredLogs entries.
  @override
  Future<bool> saveLogs(List<CounterLogEntry> logs) async {
    try {
      final prefs = await _getPrefs();
      final boundedLogs = logs.length > maxStoredLogs
          ? logs.sublist(0, maxStoredLogs)
          : logs;
      final listMap = boundedLogs.map((log) => log.toJson()).toList();
      final jsonString = jsonEncode(listMap);
      return await prefs.setString(_logsStorageKey, jsonString);
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to save logs - $e\n$stackTrace');
      return false;
    }
  }

  /// Clears saved activity logs.
  @override
  Future<bool> clearLogs() async {
    try {
      final prefs = await _getPrefs();
      return await prefs.remove(_logsStorageKey);
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to clear logs - $e\n$stackTrace');
      return false;
    }
  }

  /// Clears all saved counters and logs from storage.
  @override
  Future<bool> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
      await prefs.remove(_logsStorageKey);
      return true;
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to clear storage - $e\n$stackTrace');
      return false;
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/counter_model.dart';

/// Service responsible for local persistence using SharedPreferences and JSON encoding.
class CounterStorageService {
  static const String _storageKey = 'multi_counter_items_v1';

  final SharedPreferences? _prefsInstance;

  /// Allows passing an optional SharedPreferences instance for dependency injection & testing.
  CounterStorageService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  /// Loads all saved counters from local storage.
  /// Returns an empty list if no data exists or on error.
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

  /// Clears all saved counters from storage.
  Future<bool> clearAll() async {
    try {
      final prefs = await _getPrefs();
      return await prefs.remove(_storageKey);
    } catch (e, stackTrace) {
      debugPrint('CounterStorageService: Failed to clear counters - $e\n$stackTrace');
      return false;
    }
  }
}

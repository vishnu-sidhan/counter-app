import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data/models/counter_model.dart';
import '../data/models/counter_log_entry.dart';
import '../data/services/counter_storage_service.dart';

/// Supported sort modes for the counters list.
enum SortOption {
  recentlyUpdated('Recently Updated'),
  highestCount('Highest Count'),
  alphabetical('Alphabetical');

  final String label;
  const SortOption(this.label);
}

/// Native state controller for managing multi-counter items,
/// handling optimistic mutations, search, sort, and background persistence.
class CounterController extends ChangeNotifier {
  final CounterStorageService _storageService;
  final Uuid _uuid;

  List<CounterModel> _counters = [];
  List<CounterLogEntry> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  SortOption _sortOption;
  String? _selectedLogCounterId;

  CounterController({
    CounterStorageService? storageService,
    Uuid? uuid,
    SortOption initialSortOption = SortOption.alphabetical,
  })  : _storageService = storageService ?? CounterStorageService(),
        _uuid = uuid ?? const Uuid(),
        _sortOption = initialSortOption;

  /// Whether the controller is currently loading stored data.
  bool get isLoading => _isLoading;

  /// Current search query string.
  String get searchQuery => _searchQuery;

  /// Active sorting criterion.
  SortOption get sortOption => _sortOption;

  /// Total count of all items across all counters.
  int get totalCountSum =>
      _counters.fold(0, (sum, counter) => sum + counter.count);

  /// Number of active counters.
  int get totalCountersCount => _counters.length;

  /// Filtered and sorted counters according to search and sort criteria.
  List<CounterModel> get filteredCounters {
    final query = _searchQuery.trim().toLowerCase();
    var list = _counters.where((counter) {
      if (query.isEmpty) return true;
      return counter.title.toLowerCase().contains(query);
    }).toList();

    switch (_sortOption) {
      case SortOption.recentlyUpdated:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.highestCount:
        list.sort((a, b) => b.count.compareTo(a.count));
        break;
      case SortOption.alphabetical:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return list;
  }

  /// All activity logs (newest first).
  List<CounterLogEntry> get logs => List.unmodifiable(_logs);

  /// Selected counter ID to filter logs, or null for all counters.
  String? get selectedLogCounterId => _selectedLogCounterId;

  /// Filtered activity logs based on selected counter filter.
  List<CounterLogEntry> get filteredLogs {
    if (_selectedLogCounterId == null) {
      return List.unmodifiable(_logs);
    }
    return _logs.where((l) => l.counterId == _selectedLogCounterId).toList();
  }

  /// Initializes storage and loads persisted counters and logs.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _counters = await _storageService.loadCounters();
      _logs = await _storageService.loadLogs();
    } catch (e) {
      debugPrint('Error initializing CounterController: $e');
      _counters = [];
      _logs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the active search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Sets the active sorting mode.
  void setSortOption(SortOption option) {
    if (_sortOption == option) return;
    _sortOption = option;
    notifyListeners();
  }

  /// Adds a new counter and persists to storage.
  Future<CounterModel> addCounter({
    required String title,
    int initialCount = 0,
    int step = 1,
    required int colorHex,
    int? target,
    bool allowNegative = false,
  }) async {
    final now = DateTime.now();
    final newCounter = CounterModel(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Counter ${_counters.length + 1}' : title.trim(),
      count: initialCount,
      step: step <= 0 ? 1 : step,
      colorHex: colorHex,
      target: (target != null && target > 0) ? target : null,
      allowNegative: allowNegative,
      createdAt: now,
      updatedAt: now,
    );

    // Insert at beginning for immediate visibility
    _counters.insert(0, newCounter);
    notifyListeners();

    _silentSave();
    return newCounter;
  }

  /// Updates an existing counter's configuration.
  Future<bool> updateCounter({
    required String id,
    required String title,
    int? count,
    required int step,
    required int colorHex,
    int? target,
    bool clearTarget = false,
    required bool allowNegative,
  }) async {
    final index = _counters.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final existing = _counters[index];
    final updatedCount = count ?? existing.count;
    final boundedCount = (!allowNegative && updatedCount < 0) ? 0 : updatedCount;

    _counters[index] = existing.copyWith(
      title: title.trim().isEmpty ? existing.title : title.trim(),
      count: boundedCount,
      step: step <= 0 ? 1 : step,
      colorHex: colorHex,
      target: target,
      clearTarget: clearTarget,
      allowNegative: allowNegative,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
    _silentSave();
    return true;
  }

  /// Increments counter by its step amount with haptic feedback.
  Future<void> increment(String id) async {
    final index = _counters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final existing = _counters[index];
    final newCount = existing.count + existing.step;

    _counters[index] = existing.copyWith(
      count: newCount,
      updatedAt: DateTime.now(),
    );

    _addLogEntry(
      counterId: existing.id,
      counterTitle: existing.title,
      counterColorHex: existing.colorHex,
      actionType: CounterActionType.increment,
      changeAmount: existing.step,
      resultingCount: newCount,
    );

    HapticFeedback.lightImpact();
    notifyListeners();
    _silentSave();
  }

  /// Decrements counter by its step amount with haptic feedback.
  Future<void> decrement(String id) async {
    final index = _counters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final existing = _counters[index];
    var newCount = existing.count - existing.step;

    if (!existing.allowNegative && newCount < 0) {
      newCount = 0;
    }

    if (newCount == existing.count) {
      // Nothing changed (already at 0 minimum bound)
      HapticFeedback.selectionClick();
      return;
    }

    _counters[index] = existing.copyWith(
      count: newCount,
      updatedAt: DateTime.now(),
    );

    _addLogEntry(
      counterId: existing.id,
      counterTitle: existing.title,
      counterColorHex: existing.colorHex,
      actionType: CounterActionType.decrement,
      changeAmount: -(existing.count - newCount),
      resultingCount: newCount,
    );

    HapticFeedback.selectionClick();
    notifyListeners();
    _silentSave();
  }

  /// Resets a counter's count to 0 with feedback.
  Future<void> reset(String id) async {
    final index = _counters.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final existing = _counters[index];
    final oldCount = existing.count;

    _counters[index] = existing.copyWith(
      count: 0,
      updatedAt: DateTime.now(),
    );

    _addLogEntry(
      counterId: existing.id,
      counterTitle: existing.title,
      counterColorHex: existing.colorHex,
      actionType: CounterActionType.reset,
      changeAmount: -oldCount,
      resultingCount: 0,
    );

    HapticFeedback.mediumImpact();
    notifyListeners();
    _silentSave();
  }

  /// Sets the active counter filter for activity logs (null shows all counters).
  void filterLogsByCounter(String? counterId) {
    if (_selectedLogCounterId == counterId) return;
    _selectedLogCounterId = counterId;
    notifyListeners();
  }

  /// Clears all stored activity history.
  Future<void> clearAllLogs() async {
    _logs.clear();
    notifyListeners();
    await _storageService.clearLogs();
  }

  /// Records an activity log entry and persists to storage in the background.
  void _addLogEntry({
    required String counterId,
    required String counterTitle,
    required int counterColorHex,
    required CounterActionType actionType,
    required int changeAmount,
    required int resultingCount,
  }) {
    final entry = CounterLogEntry(
      id: _uuid.v4(),
      counterId: counterId,
      counterTitle: counterTitle,
      counterColorHex: counterColorHex,
      actionType: actionType,
      changeAmount: changeAmount,
      resultingCount: resultingCount,
      timestamp: DateTime.now(),
    );

    _logs.insert(0, entry);
    if (_logs.length > CounterStorageService.maxStoredLogs) {
      _logs = _logs.sublist(0, CounterStorageService.maxStoredLogs);
    }
    _storageService.saveLogs(List.unmodifiable(_logs));
  }

  /// Deletes a counter by ID. Returns a tuple with the deleted counter and its index.
  (CounterModel?, int) deleteCounter(String id) {
    final index = _counters.indexWhere((c) => c.id == id);
    if (index == -1) return (null, -1);

    final deletedItem = _counters.removeAt(index);
    notifyListeners();
    _silentSave();
    return (deletedItem, index);
  }

  /// Restores a previously deleted counter at the given index (for Undo).
  void restoreCounter(CounterModel counter, int targetIndex) {
    final safeIndex = targetIndex.clamp(0, _counters.length);
    _counters.insert(safeIndex, counter);
    notifyListeners();
    _silentSave();
  }

  /// Asynchronously persists current counters in the background without blocking the UI thread.
  void _silentSave() {
    _storageService.saveCounters(List.unmodifiable(_counters));
  }
}

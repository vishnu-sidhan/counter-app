import '../models/stall_models.dart';
import '../models/counter_model.dart';
import '../models/counter_log_entry.dart';
import 'stall_storage.dart';
import 'counter_storage.dart';

/// In-memory implementation of [StallStorage] for testing, demoing, or transient sessions.
class InMemoryStallStorage implements StallStorage {
  List<MenuItem> _menu = [];
  List<StallOrder> _orders = [];
  final List<StallOrder> _archivedOrders = [];
  int _nextToken = 1;

  InMemoryStallStorage({
    List<MenuItem>? initialMenu,
    List<StallOrder>? initialOrders,
    int initialToken = 1,
  })  : _menu = initialMenu != null ? List.from(initialMenu) : [],
        _orders = initialOrders != null ? List.from(initialOrders) : [],
        _nextToken = initialToken;

  @override
  Future<List<MenuItem>> loadMenu() async => List.unmodifiable(_menu);

  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    _menu = List.from(items);
  }

  @override
  Future<List<StallOrder>> loadOrders() async => List.unmodifiable(_orders);

  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    _orders = List.from(orders);
  }

  @override
  Future<int> loadNextToken() async => _nextToken;

  @override
  Future<void> saveNextToken(int token) async {
    _nextToken = token;
  }

  @override
  Future<List<StallOrder>> clearCompletedOrders() async {
    _orders.removeWhere((o) => o.isCompleted);
    return List.unmodifiable(_orders);
  }

  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async {
    final now = DateTime.now();
    final toArchive = <StallOrder>[];
    final toKeep = <StallOrder>[];

    if (explicitOrders != null) {
      final explicitTokens = explicitOrders.map((o) => o.token).toSet();
      for (final o in _orders) {
        if (explicitTokens.contains(o.token)) {
          toArchive.add(o);
        } else {
          toKeep.add(o);
        }
      }
    } else {
      for (final o in _orders) {
        if (o.isCompleted &&
            o.completedAt != null &&
            now.difference(o.completedAt!) > threshold) {
          toArchive.add(o);
        } else {
          toKeep.add(o);
        }
      }
    }

    if (toArchive.isEmpty) return 0;

    _archivedOrders.addAll(toArchive);
    _orders = toKeep;
    return toArchive.length;
  }

  @override
  Future<List<StallOrder>> loadArchivedOrders() async =>
      List.unmodifiable(_archivedOrders);

  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {
    _orders.clear();
    _archivedOrders.clear();
    if (resetToken) {
      _nextToken = 1;
    }
  }
}

/// In-memory implementation of [CounterStorage] for testing or demoing.
class InMemoryCounterStorage implements CounterStorage {
  List<CounterModel> _counters = [];
  List<CounterLogEntry> _logs = [];

  InMemoryCounterStorage({
    List<CounterModel>? initialCounters,
    List<CounterLogEntry>? initialLogs,
  })  : _counters = initialCounters != null ? List.from(initialCounters) : [],
        _logs = initialLogs != null ? List.from(initialLogs) : [];

  @override
  Future<List<CounterModel>> loadCounters() async => List.unmodifiable(_counters);

  @override
  Future<bool> saveCounters(List<CounterModel> counters) async {
    _counters = List.from(counters);
    return true;
  }

  @override
  Future<List<CounterLogEntry>> loadLogs() async => List.unmodifiable(_logs);

  @override
  Future<bool> saveLogs(List<CounterLogEntry> logs) async {
    _logs = List.from(logs);
    return true;
  }

  @override
  Future<bool> clearLogs() async {
    _logs.clear();
    return true;
  }

  @override
  Future<bool> clearAll() async {
    _counters.clear();
    _logs.clear();
    return true;
  }
}

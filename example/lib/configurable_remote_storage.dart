import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:counter_app/counter_app.dart';

/// Configurable remote storage adapter implementing [StallStorage].
///
/// Communicates with a user-specified REST API or cloud backend endpoint
/// configured from the example application's settings UI.
class ConfigurableRemoteStorage implements StallStorage {
  final String baseUrl;
  final String? authToken;
  final String? stallId;
  final bool enableOfflineCache;
  final StallStorage fallbackStorage;
  final http.Client _client;

  // In-memory cache for responsive UI rendering
  List<MenuItem>? _cachedMenu;
  List<StallOrder>? _cachedOrders;
  List<StallOrder>? _cachedArchivedOrders;
  int? _cachedNextToken;

  ConfigurableRemoteStorage({
    required String baseUrl,
    this.authToken,
    this.stallId,
    this.enableOfflineCache = true,
    StallStorage? fallbackStorage,
    http.Client? client,
  })  : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        fallbackStorage = fallbackStorage ?? StallStorageService(),
        _client = client ?? http.Client();

  Map<String, String> get _headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken!.trim().isNotEmpty) {
      final token = authToken!.trim();
      map['Authorization'] =
          token.startsWith('Bearer ') ? token : 'Bearer $token';
      map['apikey'] = token; // Compatibility with Supabase anon keys
    }
    if (stallId != null && stallId!.trim().isNotEmpty) {
      map['X-Stall-Id'] = stallId!.trim();
    }
    return map;
  }

  String _endpoint(String path) {
    if (stallId != null && stallId!.trim().isNotEmpty) {
      return '$baseUrl/${stallId!.trim()}$path';
    }
    return '$baseUrl$path';
  }

  /// Sends a lightweight probe request to verify the server endpoint and credentials.
  Future<({bool success, String message})> testConnection() async {
    try {
      final uri = Uri.parse(_endpoint('/menu'));
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          message: 'Connection successful (HTTP ${response.statusCode})',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return (
          success: false,
          message: 'Authentication failed (HTTP ${response.statusCode}). Check your token.',
        );
      } else {
        return (
          success: false,
          message: 'Server responded with HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return (
        success: false,
        message: 'Could not connect to $baseUrl: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MENU OPERATIONS
  // ---------------------------------------------------------------------------

  @override
  Future<List<MenuItem>> loadMenu() async {
    try {
      final response = await _client
          .get(Uri.parse(_endpoint('/menu')), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List decoded = jsonDecode(response.body) as List;
        _cachedMenu = decoded
            .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (enableOfflineCache) {
          await fallbackStorage.saveMenu(_cachedMenu!);
        }
        return _cachedMenu!;
      }
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: loadMenu failed - $e');
    }

    if (_cachedMenu != null) return _cachedMenu!;
    if (enableOfflineCache) {
      _cachedMenu = await fallbackStorage.loadMenu();
      return _cachedMenu!;
    }
    return [];
  }

  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    _cachedMenu = List.from(items);
    if (enableOfflineCache) {
      await fallbackStorage.saveMenu(items);
    }

    try {
      await _client
          .post(
            Uri.parse(_endpoint('/menu')),
            headers: _headers,
            body: jsonEncode(items.map((e) => e.toJson()).toList()),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: saveMenu remote sync failed - $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ORDERS OPERATIONS
  // ---------------------------------------------------------------------------

  @override
  Future<List<StallOrder>> loadOrders() async {
    try {
      final response = await _client
          .get(Uri.parse(_endpoint('/orders')), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List decoded = jsonDecode(response.body) as List;
        _cachedOrders = decoded
            .map((e) => StallOrder.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (enableOfflineCache) {
          await fallbackStorage.saveOrders(_cachedOrders!);
        }
        return _cachedOrders!;
      }
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: loadOrders failed - $e');
    }

    if (_cachedOrders != null) return _cachedOrders!;
    if (enableOfflineCache) {
      _cachedOrders = await fallbackStorage.loadOrders();
      return _cachedOrders!;
    }
    return [];
  }

  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    _cachedOrders = List.from(orders);
    if (enableOfflineCache) {
      await fallbackStorage.saveOrders(orders);
    }

    try {
      await _client
          .post(
            Uri.parse(_endpoint('/orders')),
            headers: _headers,
            body: jsonEncode(orders.map((e) => e.toJson()).toList()),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: saveOrders remote sync failed - $e');
    }
  }

  // ---------------------------------------------------------------------------
  // TOKEN COUNTER OPERATIONS
  // ---------------------------------------------------------------------------

  @override
  Future<int> loadNextToken() async {
    try {
      final response = await _client
          .get(Uri.parse(_endpoint('/token')), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final val = int.tryParse(response.body.trim());
        if (val != null) {
          _cachedNextToken = val;
          if (enableOfflineCache) {
            await fallbackStorage.saveNextToken(val);
          }
          return val;
        }
      }
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: loadNextToken failed - $e');
    }

    if (_cachedNextToken != null) return _cachedNextToken!;
    if (enableOfflineCache) {
      _cachedNextToken = await fallbackStorage.loadNextToken();
      return _cachedNextToken!;
    }
    return 1;
  }

  @override
  Future<void> saveNextToken(int token) async {
    _cachedNextToken = token;
    if (enableOfflineCache) {
      await fallbackStorage.saveNextToken(token);
    }

    try {
      await _client
          .post(
            Uri.parse(_endpoint('/token')),
            headers: _headers,
            body: token.toString(),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: saveNextToken remote sync failed - $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ARCHIVES & CLEANUP
  // ---------------------------------------------------------------------------

  @override
  Future<List<StallOrder>> clearCompletedOrders() async {
    final current = await loadOrders();
    final remaining = current.where((o) => !o.isCompleted).toList();
    await saveOrders(remaining);
    return remaining;
  }

  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async {
    final currentOrders = await loadOrders();
    final now = DateTime.now();

    final toKeep = <StallOrder>[];
    final toArchive = <StallOrder>[];

    if (explicitOrders != null) {
      final explicitTokens = explicitOrders.map((o) => o.token).toSet();
      for (final order in currentOrders) {
        if (explicitTokens.contains(order.token)) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    } else {
      for (final order in currentOrders) {
        if (order.isCompleted &&
            order.completedAt != null &&
            now.difference(order.completedAt!) > threshold) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    }

    if (toArchive.isEmpty) return 0;

    final existingArchived = await loadArchivedOrders();
    final combinedArchive = [...existingArchived, ...toArchive];
    _cachedArchivedOrders = combinedArchive;

    await saveOrders(toKeep);
    if (enableOfflineCache) {
      await fallbackStorage.archiveCompletedOrders(
        explicitOrders: explicitOrders,
        threshold: threshold,
      );
    }
    return toArchive.length;
  }

  @override
  Future<List<StallOrder>> loadArchivedOrders() async {
    if (_cachedArchivedOrders != null) return _cachedArchivedOrders!;
    if (enableOfflineCache) {
      _cachedArchivedOrders = await fallbackStorage.loadArchivedOrders();
      return _cachedArchivedOrders!;
    }
    return [];
  }

  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {
    _cachedOrders = [];
    _cachedArchivedOrders = [];
    if (resetToken) {
      _cachedNextToken = 1;
    }
    if (enableOfflineCache) {
      await fallbackStorage.clearAllOrders(resetToken: resetToken);
    }

    try {
      await _client
          .delete(Uri.parse(_endpoint('/orders')), headers: _headers)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('ConfigurableRemoteStorage: clearAllOrders failed - $e');
    }
  }

  List<ItemCategory>? _cachedCategories;

  @override
  Future<List<ItemCategory>> loadCategories() async {
    if (_cachedCategories != null) return _cachedCategories!;
    if (enableOfflineCache) {
      _cachedCategories = await fallbackStorage.loadCategories();
      return _cachedCategories!;
    }
    return [];
  }

  @override
  Future<void> saveCategories(List<ItemCategory> categories) async {
    _cachedCategories = List.from(categories);
    if (enableOfflineCache) {
      await fallbackStorage.saveCategories(categories);
    }
  }
}

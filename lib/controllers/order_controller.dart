import 'package:flutter/foundation.dart';
import '../data/models/stall_models.dart';
import '../data/services/stall_storage_service.dart';

/// State controller for Stall POS operations:
/// managing menu catalog, active cart, orders queue, in-place order editing,
/// deletion, and reactive aggregated kitchen preparations.
class OrderController extends ChangeNotifier {
  final StallStorageService _storageService;

  List<MenuItem> _menu = [];
  List<StallOrder> _orders = [];
  final Map<String, int> _cart = {}; // menuItem.id -> quantity
  int _nextToken = 1;
  int? _editingOrderId;
  String _selectedCategory = 'All';
  bool _isLoading = true;

  OrderController({StallStorageService? storageService})
      : _storageService = storageService ?? StallStorageService();

  // ---------------------------------------------------------------------------
  // GETTERS
  // ---------------------------------------------------------------------------

  bool get isLoading => _isLoading;
  List<MenuItem> get menu => List.unmodifiable(_menu);
  List<StallOrder> get orders => List.unmodifiable(_orders);
  Map<String, int> get cart => Map.unmodifiable(_cart);
  int get nextToken => _nextToken;
  int? get editingOrderId => _editingOrderId;
  bool get isEditing => _editingOrderId != null;
  String get selectedCategory => _selectedCategory;
  StallStorageService get storageService => _storageService;

  /// Returns all active (non-completed) orders in FIFO order.
  List<StallOrder> get activeOrders =>
      _orders.where((o) => !o.isCompleted).toList();

  /// Returns active orders where payment is confirmed.
  List<StallOrder> get confirmedActiveOrders =>
      activeOrders.where((o) => o.isPaid).toList();

  /// Returns active orders where payment is still pending confirmation.
  List<StallOrder> get toConfirmPaymentOrders =>
      activeOrders.where((o) => !o.isPaid).toList();

  /// Total count of items in the current active cart.
  int get cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  /// Computes the total monetary price of items in the cart.
  double get cartTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final item = _menu.firstWhere(
        (m) => m.id == itemId,
        orElse: () => const MenuItem(id: '', name: '', price: 0.0),
      );
      total += item.price * qty;
    });
    return total;
  }

  /// List of distinct categories present in the current menu.
  List<String> get categories {
    final set = <String>{'All'};
    for (final item in _menu) {
      if (item.category.trim().isNotEmpty) {
        set.add(item.category.trim());
      }
    }
    return set.toList();
  }

  /// Filtered menu based on selected category chip.
  List<MenuItem> get filteredMenu {
    if (_selectedCategory == 'All') return _menu;
    return _menu.where((m) => m.category == _selectedCategory).toList();
  }

  /// Menu items grouped by category for expandable accordion rendering.
  Map<String, List<MenuItem>> get groupedMenu {
    final map = <String, List<MenuItem>>{};
    final items = filteredMenu;
    for (final item in items) {
      final cat =
          item.category.trim().isEmpty ? 'General' : item.category.trim();
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  /// Consolidated items view across all active orders with confirmed payment.
  /// Aggregates total quantities per item and tracks ticket tags.
  List<AggregatedOrderItem> get combinedActiveOrders {
    final confirmed = confirmedActiveOrders;
    if (confirmed.isEmpty) return const [];

    // Map: ItemKey -> Aggregated details
    final Map<String, _ItemAccumulator> accumulators = {};

    for (final order in confirmed) {
      if (order.items.isNotEmpty) {
        // Structured items map available
        order.items.forEach((itemId, qty) {
          if (qty <= 0) return;
          final item = _menu.firstWhere(
            (m) => m.id == itemId,
            orElse: () => MenuItem(
              id: itemId,
              name: itemId,
              price: 0,
              category: 'General',
            ),
          );

          final acc = accumulators.putIfAbsent(
            item.id.isNotEmpty ? item.id : item.name,
            () => _ItemAccumulator(
              itemId: item.id,
              name: item.name,
              category: item.category,
              colorHex: item.colorHex,
            ),
          );
          acc.totalQty += qty;
          acc.tickets.add(OrderTicketQuantity(token: order.token, quantity: qty));
        });
      } else if (order.itemsSummary.isNotEmpty) {
        // Fallback parser for legacy or raw summaries: e.g. "3x Masala Chai, 2x Veg Samosa"
        final parts = order.itemsSummary.split(',');
        final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
        for (final rawPart in parts) {
          final match = regex.firstMatch(rawPart.trim());
          if (match != null) {
            final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
            final name = match.group(2)?.trim() ?? rawPart.trim();
            final matchedItem = _menu.firstWhere(
              (m) => m.name.toLowerCase() == name.toLowerCase(),
              orElse: () => MenuItem(
                id: name,
                name: name,
                price: 0,
                category: 'General',
              ),
            );

            final acc = accumulators.putIfAbsent(
              matchedItem.id.isNotEmpty ? matchedItem.id : matchedItem.name,
              () => _ItemAccumulator(
                itemId: matchedItem.id,
                name: matchedItem.name,
                category: matchedItem.category,
                colorHex: matchedItem.colorHex,
              ),
            );
            acc.totalQty += qty;
            acc.tickets.add(OrderTicketQuantity(token: order.token, quantity: qty));
          }
        }
      }
    }

    final result = accumulators.values.map((acc) {
      return AggregatedOrderItem(
        itemId: acc.itemId,
        itemName: acc.name,
        category: acc.category,
        totalQuantity: acc.totalQty,
        tickets: List.unmodifiable(acc.tickets),
        colorHex: acc.colorHex,
      );
    }).toList();

    // Sort by total quantity descending so highest prep items are on top
    result.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    return result;
  }

  /// Extracts individual items with their corresponding category and color for an order.
  List<({String name, int quantity, String category, int? colorHex})>
      getOrderItemsWithCategory(StallOrder order) {
    final result =
        <({String name, int quantity, String category, int? colorHex})>[];

    if (order.items.isNotEmpty) {
      order.items.forEach((itemId, qty) {
        if (qty <= 0) return;
        final item = _menu.firstWhere(
          (m) => m.id == itemId,
          orElse: () => MenuItem(
            id: itemId,
            name: itemId,
            price: 0,
            category: 'General',
          ),
        );
        result.add((
          name: item.name,
          quantity: qty,
          category: item.category,
          colorHex: item.colorHex,
        ));
      });
    } else if (order.itemsSummary.isNotEmpty) {
      final parts = order.itemsSummary.split(',');
      final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
      for (final rawPart in parts) {
        final match = regex.firstMatch(rawPart.trim());
        if (match != null) {
          final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
          final name = match.group(2)?.trim() ?? rawPart.trim();
          final item = _menu.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase(),
            orElse: () => MenuItem(
              id: '',
              name: name,
              price: 0,
              category: 'General',
            ),
          );
          result.add((
            name: name,
            quantity: qty,
            category: item.category,
            colorHex: item.colorHex,
          ));
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // INITIALIZATION & PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> loadPersistedData() async {
    _isLoading = true;
    notifyListeners();

    _menu = await _storageService.loadMenu();
    _orders = await _storageService.loadOrders();
    _nextToken = await _storageService.loadNextToken();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveState() async {
    await _storageService.saveMenu(_menu);
    await _storageService.saveOrders(_orders);
    await _storageService.saveNextToken(_nextToken);
  }

  // ---------------------------------------------------------------------------
  // CATEGORY SELECTION
  // ---------------------------------------------------------------------------

  void selectCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // CART ACTIONS
  // ---------------------------------------------------------------------------

  void addToCart(MenuItem item) {
    _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    if (_cart.isNotEmpty) {
      _cart.clear();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS: EDIT, DELETE, PUNCH / UPDATE, COMPLETE
  // ---------------------------------------------------------------------------

  /// Initiates editing for an active order:
  /// 1. Populates cart with order's items.
  /// 2. Sets editingOrderId to order.token.
  /// Returns the customerName of the order (or empty string) to populate UI.
  String startEditingOrder(StallOrder order) {
    _cart.clear();

    if (order.items.isNotEmpty) {
      _cart.addAll(order.items);
    } else if (order.itemsSummary.isNotEmpty) {
      // Parse items summary if structured items map is missing
      final parts = order.itemsSummary.split(',');
      final regex = RegExp(r'^\s*(\d+)x\s+(.+)$');
      for (final p in parts) {
        final match = regex.firstMatch(p.trim());
        if (match != null) {
          final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
          final name = match.group(2)?.trim() ?? '';
          final found = _menu.firstWhere(
            (m) => m.name.toLowerCase() == name.toLowerCase(),
            orElse: () => const MenuItem(id: '', name: '', price: 0),
          );
          if (found.id.isNotEmpty) {
            _cart[found.id] = qty;
          }
        }
      }
    }

    _editingOrderId = order.token;
    notifyListeners();
    return order.customerName ?? '';
  }

  /// Cancels editing mode and clears cart.
  void cancelEditingOrder() {
    _editingOrderId = null;
    _cart.clear();
    notifyListeners();
  }

  /// Places a new order or updates an existing order in-place if editingOrderId is set.
  /// Returns a tuple of (token, isEdit).
  /// Places a new order or updates an existing order in-place if editingOrderId is set.
  /// Returns a tuple of (token, isEdit).
  Future<({int token, bool isEdit})> punchOrUpdateOrder({
    required String? customerName,
    String? paymentMethod,
    bool? isPaid,
  }) async {
    if (_cart.isEmpty) {
      throw StateError('Cannot punch an empty order');
    }

    final summaryParts = <String>[];
    _cart.forEach((itemId, qty) {
      final item = _menu.firstWhere(
        (m) => m.id == itemId,
        orElse: () => MenuItem(id: itemId, name: 'Item', price: 0),
      );
      summaryParts.add('${qty}x ${item.name}');
    });
    final summary = summaryParts.join(', ');
    final total = cartTotal;
    final cleanCustomerName =
        (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : null;

    if (_editingOrderId != null) {
      // In-place update of existing order
      final editToken = _editingOrderId!;
      final idx = _orders.indexWhere((o) => o.token == editToken);

      if (idx != -1) {
        final existing = _orders[idx];
        final updatedIsPaid = isPaid ?? existing.isPaid;
        final updatedPaymentMethod = paymentMethod ?? existing.paymentMethod;
        _orders[idx] = existing.copyWith(
          itemsSummary: summary,
          total: total,
          items: Map.from(_cart),
          customerName: cleanCustomerName,
          clearCustomerName: cleanCustomerName == null,
          isPaid: updatedIsPaid,
          paymentMethod: updatedPaymentMethod,
        );
      }

      _editingOrderId = null;
      _cart.clear();
      await _saveState();
      notifyListeners();
      return (token: editToken, isEdit: true);
    } else {
      // New Order (defaults to unpaid unless specified)
      final effectiveIsPaid = isPaid ?? false;
      final newOrder = StallOrder(
        token: _nextToken,
        itemsSummary: summary,
        total: total,
        timestamp: DateTime.now(),
        customerName: cleanCustomerName,
        isPaid: effectiveIsPaid,
        paymentMethod: paymentMethod,
        items: Map.from(_cart),
      );

      _orders.add(newOrder);
      final assignedToken = _nextToken;
      _nextToken++;
      _cart.clear();
      await _saveState();
      notifyListeners();
      return (token: assignedToken, isEdit: false);
    }
  }

  /// Confirms payment for an order and persists the change.
  Future<void> confirmPayment({
    required int token,
    required String paymentMethod,
  }) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx != -1) {
      _orders[idx] = _orders[idx].copyWith(
        isPaid: true,
        paymentMethod: paymentMethod,
      );
      await _saveState();
      notifyListeners();
    }
  }

  /// Deletes an order from state and persists.
  /// If the deleted order is currently being edited, cancels editing mode.
  Future<void> deleteOrder(int token) async {
    if (_editingOrderId == token) {
      cancelEditingOrder();
    }
    _orders.removeWhere((o) => o.token == token);
    await _saveState();
    notifyListeners();
  }

  /// Marks an order as completed.
  Future<void> completeOrder(int token) async {
    final idx = _orders.indexWhere((o) => o.token == token);
    if (idx != -1) {
      _orders[idx].isCompleted = true;
      _orders[idx].completedAt = DateTime.now();
      await _saveState();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // MENU ITEM MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<void> addMenuItem(MenuItem item) async {
    _menu.add(item);
    await _saveState();
    notifyListeners();
  }

  Future<void> updateMenuItem(MenuItem updated) async {
    final idx = _menu.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      _menu[idx] = updated;
      await _saveState();
      notifyListeners();
    }
  }

  Future<void> deleteMenuItem(String id) async {
    _menu.removeWhere((m) => m.id == id);
    _cart.remove(id);
    if (_selectedCategory != 'All' &&
        !_menu.any((m) => m.category == _selectedCategory)) {
      _selectedCategory = 'All';
    }
    await _saveState();
    notifyListeners();
  }

  Future<void> setMenu(List<MenuItem> newMenu, {bool replace = true}) async {
    if (replace) {
      _menu = List.from(newMenu);
      _cart.clear();
      _selectedCategory = 'All';
    } else {
      _menu.addAll(newMenu);
    }
    await _saveState();
    notifyListeners();
  }
}

class _ItemAccumulator {
  final String itemId;
  final String name;
  final String category;
  final int? colorHex;
  int totalQty = 0;
  final List<OrderTicketQuantity> tickets = [];

  _ItemAccumulator({
    required this.itemId,
    required this.name,
    required this.category,
    this.colorHex,
  });
}

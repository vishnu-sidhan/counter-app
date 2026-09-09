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

  /// Returns only the items/quantities that have been paid for in the given order.
  /// If an item contains add-ons (composite key with '+'), it is only considered confirmed
  /// if the exact linked item was paid for. If an add-on was added to an item, the linked
  /// item moves to pending and is excluded from confirmed items.
  Map<String, int> getConfirmedOrderItems(StallOrder order) {
    if (order.isPaid) {
      return Map.unmodifiable(order.items);
    }
    if (order.paidItems.isEmpty || order.paidAmount <= 0) {
      return const {};
    }

    final confirmed = <String, int>{};
    for (final entry in order.items.entries) {
      final itemId = entry.key;
      final totalQty = entry.value;
      if (totalQty <= 0) continue;

      final paidQty = order.paidItems[itemId] ?? 0;
      if (paidQty > 0) {
        final qty = paidQty > totalQty ? totalQty : paidQty;
        confirmed[itemId] = qty;
      }
    }
    return Map.unmodifiable(confirmed);
  }

  /// Returns only the items/quantities that have NOT yet been paid for in the given order.
  /// If an item contains add-ons that were added without being fully paid,
  /// the entire linked item moves to pending.
  Map<String, int> getPendingOrderItems(StallOrder order) {
    if (order.isPaid) {
      return const {};
    }
    if (order.paidItems.isEmpty || order.paidAmount <= 0) {
      return Map.unmodifiable(order.items);
    }

    final pending = <String, int>{};
    for (final entry in order.items.entries) {
      final itemId = entry.key;
      final totalQty = entry.value;
      if (totalQty <= 0) continue;

      final paidQty = order.paidItems[itemId] ?? 0;
      final unpaidQty = totalQty - paidQty;
      if (unpaidQty > 0) {
        pending[itemId] = unpaidQty;
      }
    }
    return Map.unmodifiable(pending);
  }

  /// Returns all active (non-completed) orders in FIFO order.
  List<StallOrder> get activeOrders =>
      _orders.where((o) => !o.isCompleted).toList();

  /// Returns active orders that have confirmed (paid) items.
  List<StallOrder> get confirmedActiveOrders =>
      activeOrders.where((o) => o.isPaid || getConfirmedOrderItems(o).isNotEmpty).toList();

  /// Returns active orders that have pending (unpaid) items to confirm payment.
  List<StallOrder> get toConfirmPaymentOrders =>
      activeOrders.where((o) => !o.isPaid && getPendingOrderItems(o).isNotEmpty).toList();

  /// Total count of items in the current active cart.
  int get cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  /// Resolves an item by its ID.
  /// Handles base menu items, slash variant selections (e.g. itemId_var_option),
  /// and composite items containing linked add-ons (e.g. baseId+addonId1+addonId2).
  MenuItem findItem(String itemId) {
    // 1. Direct match in menu
    for (final m in _menu) {
      if (m.id == itemId) return m;
    }

    // 2. Composite items with add-ons (e.g. "baseItemId+addonId1")
    if (itemId.contains('+')) {
      final parts = itemId.split('+');
      final baseId = parts[0];
      final addonIds = parts.sublist(1);
      final baseItem = findItem(baseId);

      if (baseItem.id.isNotEmpty) {
        final addonItems = <MenuItem>[];
        for (final aId in addonIds) {
          final addon = findItem(aId);
          if (addon.id.isNotEmpty) {
            addonItems.add(addon);
          }
        }

        if (addonItems.isNotEmpty) {
          // Group add-ons by name and count occurrences to format as "x-times" if count > 1
          final Map<String, ({int count, double singlePrice})> addonGroups = {};
          for (final addon in addonItems) {
            final existing = addonGroups[addon.name];
            if (existing != null) {
              addonGroups[addon.name] = (
                count: existing.count + 1,
                singlePrice: existing.singlePrice,
              );
            } else {
              addonGroups[addon.name] = (
                count: 1,
                singlePrice: addon.price,
              );
            }
          }

          final prefix = addonGroups.entries.map((entry) {
            final name = entry.key;
            final count = entry.value.count;
            return count > 1 ? '[$count' 'x $name]' : '[$name]';
          }).join(' ');

          final addedPrice = addonGroups.values.fold(
            0.0,
            (sum, g) => sum + g.singlePrice * g.count,
          );

          return MenuItem(
            id: itemId,
            name: '$prefix ${baseItem.name}',
            price: baseItem.price + addedPrice,
            category: baseItem.category,
            colorHex: baseItem.colorHex,
            isAddon: false,
          );
        }
      }
    }

    // 3. Customized variant / category items (e.g. "item_chai_var_Tea", "item_rice_cat_Rice", or "item_123_var_Fried Rice_cat_Rice")
    if (itemId.contains('_var_') || itemId.contains('_cat_')) {
      String remaining = itemId;
      String? resolvedCat;
      final lastCatIdx = remaining.lastIndexOf('_cat_');
      if (lastCatIdx != -1) {
        resolvedCat = remaining.substring(lastCatIdx + 5);
        remaining = remaining.substring(0, lastCatIdx);
      }
      String? resolvedName;
      final lastVarIdx = remaining.lastIndexOf('_var_');
      if (lastVarIdx != -1) {
        resolvedName = remaining.substring(lastVarIdx + 5);
        remaining = remaining.substring(0, lastVarIdx);
      }
      final baseId = remaining;
      final baseItem = findItem(baseId);
      return MenuItem(
        id: itemId,
        name: resolvedName ?? baseItem.name,
        price: baseItem.price,
        category: resolvedCat ?? baseItem.category,
        colorHex: baseItem.colorHex,
        isAddon: baseItem.isAddon,
      );
    }

    return MenuItem(
      id: itemId,
      name: itemId.isNotEmpty ? itemId : 'Item',
      price: 0.0,
      category: 'General',
    );
  }

  /// Computes the total monetary price of items in the cart.
  double get cartTotal {
    double total = 0.0;
    _cart.forEach((itemId, qty) {
      final item = findItem(itemId);
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
    return _menu
        .where((m) =>
            m.category.trim().toLowerCase() == _selectedCategory.toLowerCase())
        .toList();
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
  /// Custom composite items with add-ons remain separate entries.
  List<AggregatedOrderItem> get combinedActiveOrders {
    // Filter to active orders that have confirmed items
    final eligibleOrders = _orders
        .where((o) => !o.isCompleted && (o.isPaid || getConfirmedOrderItems(o).isNotEmpty))
        .toList();
    if (eligibleOrders.isEmpty) return const [];

    // Map: ItemKey -> Aggregated details
    final Map<String, _ItemAccumulator> accumulators = {};

    for (final order in eligibleOrders) {
      // Use getConfirmedOrderItems so only items with confirmed payment are aggregated
      final itemsToAggregate = getConfirmedOrderItems(order);
      if (itemsToAggregate.isNotEmpty) {
        // Structured items map available
        itemsToAggregate.forEach((itemId, qty) {
          if (qty <= 0) return;
          final item = findItem(itemId);

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
      } else if (order.isPaid && order.itemsSummary.isNotEmpty) {
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
  /// If [customItems] is provided, extracts details for that subset of items instead of [order.items].
  List<({String name, int quantity, String category, int? colorHex, String displayName, bool isPaidItem})>
      getOrderItemsWithCategory(StallOrder order, {Map<String, int>? customItems}) {
    final result =
        <({String name, int quantity, String category, int? colorHex, String displayName, bool isPaidItem})>[];

    final targetItems = customItems ?? order.items;
    if (targetItems.isNotEmpty) {
      targetItems.forEach((itemId, qty) {
        if (qty <= 0) return;
        final item = findItem(itemId);
        final isPaidItem = order.isPaid || ((order.paidItems[itemId] ?? 0) >= qty);
        result.add((
          name: item.name,
          quantity: qty,
          category: item.category,
          colorHex: item.colorHex,
          displayName: item.displayName,
          isPaidItem: isPaidItem,
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
            displayName: item.displayName,
            isPaidItem: order.isPaid,
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

  /// Returns items currently in the cart that can receive add-ons.
  List<MenuItem> get cartBaseItems {
    final list = <MenuItem>[];
    for (final entry in _cart.entries) {
      if (entry.value > 0) {
        final item = findItem(entry.key);
        if (!item.effectiveIsAddon) {
          list.add(item);
        }
      }
    }
    return list;
  }

  /// Adds a standard item to the cart.
  /// If the item is an Add-on, throws a StateError because add-ons cannot be added alone.
  void addToCart(MenuItem item) {
    if (item.effectiveIsAddon) {
      throw StateError(
        'Add-ons cannot be added standalone. They must be linked to a main item.',
      );
    }
    _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    notifyListeners();
  }

  /// Adds a specific variant of an or-item (slash item) to the cart.
  void addVariantToCart(MenuItem baseItem, String variantName) {
    final variantId = '${baseItem.id}_var_$variantName';
    _cart[variantId] = (_cart[variantId] ?? 0) + 1;
    notifyListeners();
  }

  /// Adds an item with custom variant name and/or resolved category to the cart.
  void addCustomizedItemToCart({
    required MenuItem baseItem,
    String? resolvedName,
    String? resolvedCategory,
  }) {
    if (baseItem.effectiveIsAddon) {
      throw StateError(
        'Add-ons cannot be added standalone. They must be linked to a main item.',
      );
    }
    String customId = baseItem.id;
    if (resolvedName != null &&
        resolvedName.trim().isNotEmpty &&
        resolvedName.trim() != baseItem.name.trim()) {
      customId += '_var_${resolvedName.trim()}';
    }
    if (resolvedCategory != null &&
        resolvedCategory.trim().isNotEmpty &&
        resolvedCategory.trim() != baseItem.category.trim()) {
      customId += '_cat_${resolvedCategory.trim()}';
    }
    _cart[customId] = (_cart[customId] ?? 0) + 1;
    notifyListeners();
  }

  /// Links an add-on to an existing item in the cart.
  /// Converts 1 unit of targetCartItemId into targetCartItemId+addonId (repeated quantity times).
  /// Supports resolvedAddonName and quantity.
  void addAddonToCart({
    required String targetCartItemId,
    required MenuItem addon,
    String? resolvedAddonName,
    String? resolvedAddonCategory,
    int quantity = 1,
  }) {
    if (quantity <= 0) return;
    if (!_cart.containsKey(targetCartItemId) || _cart[targetCartItemId]! <= 0) {
      throw StateError(
        'Cannot link add-on to an item not present in the active cart.',
      );
    }

    // Decrement the target base item in cart
    if (_cart[targetCartItemId]! > 1) {
      _cart[targetCartItemId] = _cart[targetCartItemId]! - 1;
    } else {
      _cart.remove(targetCartItemId);
    }

    String addonId = addon.id;
    if (resolvedAddonName != null &&
        resolvedAddonName.trim().isNotEmpty &&
        resolvedAddonName.trim() != addon.name.trim()) {
      addonId += '_var_${resolvedAddonName.trim()}';
    }
    if (resolvedAddonCategory != null &&
        resolvedAddonCategory.trim().isNotEmpty &&
        resolvedAddonCategory.trim() != addon.category.trim()) {
      addonId += '_cat_${resolvedAddonCategory.trim()}';
    }

    // Append addonId repeated quantity times
    final tokens = List.filled(quantity, addonId).join('+');
    final compositeId = '$targetCartItemId+$tokens';
    _cart[compositeId] = (_cart[compositeId] ?? 0) + 1;
    notifyListeners();
  }

  /// Links multiple add-ons with their respective quantities to a cart item in a single action.
  void addMultipleAddonsToCart({
    required String targetCartItemId,
    required List<({MenuItem addon, String? resolvedName, int quantity})> addons,
  }) {
    final validAddons = addons.where((a) => a.quantity > 0).toList();
    if (validAddons.isEmpty) return;

    if (!_cart.containsKey(targetCartItemId) || _cart[targetCartItemId]! <= 0) {
      throw StateError(
        'Cannot link add-on to an item not present in the active cart.',
      );
    }

    // Decrement the target base item in cart
    if (_cart[targetCartItemId]! > 1) {
      _cart[targetCartItemId] = _cart[targetCartItemId]! - 1;
    } else {
      _cart.remove(targetCartItemId);
    }

    final addonTokens = <String>[];
    for (final item in validAddons) {
      String aId = item.addon.id;
      if (item.resolvedName != null &&
          item.resolvedName!.trim().isNotEmpty &&
          item.resolvedName!.trim() != item.addon.name.trim()) {
        aId += '_var_${item.resolvedName!.trim()}';
      }
      for (int i = 0; i < item.quantity; i++) {
        addonTokens.add(aId);
      }
    }

    final compositeId = '$targetCartItemId+${addonTokens.join('+')}';
    _cart[compositeId] = (_cart[compositeId] ?? 0) + 1;
    notifyListeners();
  }

  void incrementCartItem(String itemId) {
    if (_cart.containsKey(itemId)) {
      _cart[itemId] = _cart[itemId]! + 1;
      notifyListeners();
    }
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
  Future<({int token, bool isEdit})> punchOrUpdateOrder({
    required String? customerName,
    String? paymentMethod,
    bool? isPaid,
    double? paidAmount,
    Map<String, int>? paidItems,
  }) async {
    if (_cart.isEmpty) {
      throw StateError('Cannot punch an empty order');
    }

    final summaryParts = <String>[];
    _cart.forEach((itemId, qty) {
      final item = findItem(itemId);
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
        final wasPaid = existing.isPaid || existing.paidAmount > 0;
        final prevPaid = existing.paidAmount > 0
            ? existing.paidAmount
            : (existing.isPaid ? existing.total : 0.0);
        final additionalDue = (total - prevPaid) > 0 ? (total - prevPaid) : 0.0;

        double finalPaidAmount;
        bool finalIsPaid;
        Map<String, int> finalPaidItems;

        if (paidAmount != null) {
          finalPaidAmount = paidAmount;
          finalIsPaid = isPaid ?? (finalPaidAmount >= total);
          finalPaidItems = paidItems ??
              (finalIsPaid
                  ? Map.from(_cart)
                  : Map.from(existing.paidItems.isNotEmpty ? existing.paidItems : existing.items));
        } else if (isPaid != null) {
          finalIsPaid = isPaid;
          finalPaidAmount = isPaid ? total : prevPaid;
          finalPaidItems = isPaid
              ? Map.from(_cart)
              : Map.from(existing.paidItems.isNotEmpty ? existing.paidItems : existing.items);
        } else {
          if (wasPaid) {
            if (additionalDue > 0) {
              // Additional payment is required: preserve previous paid amount and items,
              // but mark order as NOT fully paid so newly added items are NOT shown in confirmed payment!
              finalPaidAmount = prevPaid;
              finalPaidItems = existing.paidItems.isNotEmpty
                  ? Map.from(existing.paidItems)
                  : (existing.items.isNotEmpty ? Map.from(existing.items) : {});
              finalIsPaid = false;
            } else {
              // Total decreased or stayed identical
              finalPaidAmount = total;
              finalPaidItems = Map.from(_cart);
              finalIsPaid = true;
            }
          } else {
            finalPaidAmount = 0.0;
            finalPaidItems = const {};
            finalIsPaid = false;
          }
        }

        final updatedPaymentMethod = paymentMethod ?? existing.paymentMethod;
        _orders[idx] = existing.copyWith(
          itemsSummary: summary,
          total: total,
          items: Map.from(_cart),
          customerName: cleanCustomerName,
          clearCustomerName: cleanCustomerName == null,
          isPaid: finalIsPaid,
          paidAmount: finalPaidAmount,
          paidItems: finalPaidItems,
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
        paidAmount: effectiveIsPaid ? (paidAmount ?? total) : (paidAmount ?? 0.0),
        paidItems: effectiveIsPaid ? (paidItems ?? Map.from(_cart)) : (paidItems ?? const {}),
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
      final existing = _orders[idx];
      _orders[idx] = existing.copyWith(
        isPaid: true,
        paidAmount: existing.total,
        paidItems: Map.from(existing.items),
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
    _cart.removeWhere((cartId, _) =>
        cartId == id ||
        cartId.startsWith('$id+') ||
        cartId.contains('+$id') ||
        cartId.startsWith('${id}_var_'));
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

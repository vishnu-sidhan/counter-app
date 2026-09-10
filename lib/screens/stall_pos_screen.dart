import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/order_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/models/stall_models.dart';
import '../theme/category_colors.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/payment_confirmation_dialog.dart';
import '../widgets/stall_pos/stall_pos_widgets.dart';
import 'order_history_screen.dart';

// Re-export models and controller for backwards compatibility
import '../data/storage/stall_storage.dart';
export '../controllers/order_controller.dart';
export '../data/models/stall_models.dart';
export '../data/storage/stall_storage.dart';

class StallPosScreen extends StatefulWidget {
  final StallStorage? storageService;
  final OrderController? controller;

  const StallPosScreen({super.key, this.storageService, this.controller});

  @override
  State<StallPosScreen> createState() => _StallPosScreenState();
}

class _StallPosScreenState extends State<StallPosScreen>
    with TickerProviderStateMixin {
  late final OrderController _controller;
  late final bool _internalController;
  late TabController _mobileTabController;
  late TabController _desktopTabController;
  final TextEditingController _customerNameController = TextEditingController();
  final Set<String> _collapsedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _controller = OrderController(
        storageService: widget.storageService,
      );
      _internalController = true;
      _controller.loadPersistedData();
    }
    _controller.addListener(_onControllerChanged);

    _mobileTabController = TabController(length: 3, vsync: this);
    _desktopTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_internalController) {
      _controller.dispose();
    }
    _mobileTabController.dispose();
    _desktopTabController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES & COLORS
  // ---------------------------------------------------------------------------

  List<String> get _categories => _controller.categories;
  List<MenuItem> get _menu => _controller.menu;
  Map<String, int> get _cart => _controller.cart;

  Map<String, int> get _resolvedCategoryColors {
    final result = <String, int>{};
    final usedColors = <int>{};
    final allCategories = _categories.where((c) => c != 'All').toList();

    for (final cat in allCategories) {
      final normalized = cat.trim().toLowerCase();
      for (final m in _menu) {
        if (m.category.trim().toLowerCase() == normalized &&
            m.colorHex != null) {
          if (!usedColors.contains(m.colorHex!)) {
            result[cat] = m.colorHex!;
            usedColors.add(m.colorHex!);
            break;
          }
        }
      }
    }

    for (final cat in allCategories) {
      if (!result.containsKey(cat)) {
        final uniqueColor = CategoryColorHelper.getUniqueColor(
          categoryName: cat,
          usedColors: usedColors,
        );
        result[cat] = uniqueColor;
        usedColors.add(uniqueColor);
      }
    }

    return result;
  }

  Color _getCategoryColor(String category) {
    if (category == 'All') {
      return Theme.of(context).colorScheme.primary;
    }
    final map = _resolvedCategoryColors;
    final hex =
        map[category] ??
        CategoryColorHelper.getUniqueColor(
          categoryName: category,
          usedColors: map.values.toSet(),
        );
    return Color(hex);
  }

  // ---------------------------------------------------------------------------
  // CART & MENU ITEM ACTIONS
  // ---------------------------------------------------------------------------

  void _addToCart(MenuItem item) {
    HapticFeedback.selectionClick();
    _controller.addToCart(item);
  }

  void _handleMenuItemTap(MenuItem item) {
    HapticFeedback.selectionClick();

    // 1. Check if item is an Add-on
    if (item.effectiveIsAddon) {
      final baseItems = _controller.cartBaseItems;
      if (baseItems.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Add-ons must be linked to an item. Please add a main item first.',
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final eligibleBaseItems = baseItems.where((b) {
        if (item.hasSlashNameVariants) {
          return item.slashNameVariants.any((v) =>
              _controller.getAddonItemCount(b.id, item.id, resolvedAddonName: v) <
              OrderController.maxPerAddonItem);
        }
        return _controller.getAddonItemCount(b.id, item.id) <
            OrderController.maxPerAddonItem;
      }).toList();

      if (eligibleBaseItems.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum 2 [${item.name}] already added to items in cart.',
            ),
            backgroundColor: Colors.deepOrange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      // If addon has slash variants (e.g. Cheese / Mayo) OR multiple eligible base items in cart
      if (item.hasAnySlashVariants || eligibleBaseItems.length > 1) {
        _showCentralizedSlashSelectionModal(item);
        return;
      }

      // Single eligible base item & no slash in addon
      final target = eligibleBaseItems.first;
      _controller.addAddonToCart(
        targetCartItemId: target.id,
        addon: item,
      );
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added [${item.name}] to ${target.displayName}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Check if item has '/' variants in name or category (e.g. Rice / Noodles or Fried Rice / Hakka Noodles)
    if (item.hasAnySlashVariants) {
      _showCentralizedSlashSelectionModal(item);
      return;
    }

    // 3. Regular item
    _addToCart(item);
  }

  void _showCentralizedSlashSelectionModal(MenuItem item) {
    SlashSelectionModal.show(
      context,
      item: item,
      controller: _controller,
      getCategoryColor: _getCategoryColor,
    );
  }

  void _showCartBottomSheet() {
    CartBottomSheet.show(
      context,
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      onCheckout: () => _fireOrder(),
      onClearCart: _clearCart,
      onPayAndPunch: () => _fireOrder(immediatePayment: true),
    );
  }



  void _clearCart() {
    _controller.clearCart();
    _customerNameController.clear();
  }

  void _cancelEdit() {
    _controller.cancelEditing();
    _customerNameController.clear();
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS: FIRE / UPDATE, EDIT, DELETE, COMPLETE
  // ---------------------------------------------------------------------------

  Future<void> _fireOrder({bool immediatePayment = false}) async {
    if (_controller.cart.isEmpty) return;

    final isEdit = _controller.isEditing;
    final custName = _customerNameController.text.trim();

    HapticFeedback.heavyImpact();

    // 1-Step Immediate Checkout flow on POS register
    if (!isEdit && immediatePayment) {
      final token = _controller.nextToken;
      final total = _controller.cartTotal;
      final result = await PaymentConfirmationDialog.show(
        context,
        orderNumber: token,
        isEditing: false,
        totalDue: total,
        customerName: custName.isNotEmpty ? custName : 'Walk-in Customer',
        newTotal: total,
      );

      if (result == null) {
        // Cashier dismissed payment dialog: return without punching
        return;
      }

      if (result.isMarkAsPending) {
        // Cashier chose to keep pending / pay later
        final outcome = await _controller.punchOrUpdateOrder(
          customerName: custName.isNotEmpty ? custName : null,
          isPaid: false,
        );
        _customerNameController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${outcome.token} placed! Payment pending.'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Payment completed in 1-step!
      final outcome = await _controller.punchOrUpdateOrder(
        customerName: custName.isNotEmpty ? custName : null,
        isPaid: true,
        paidAmount: total,
        paidItems: Map.from(_controller.cart),
        paymentMethod: result.paymentMethod,
      );
      _customerNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${outcome.token} paid via ${result.paymentMethod} and dispatched!',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (isEdit) {
      final editToken = _controller.editingOrderId!;
      final existingOrder = _controller.orders.firstWhere(
        (o) => o.token == editToken,
      );
      final wasPaid = existingOrder.isPaid || existingOrder.paidAmount > 0;
      final prevPaid = existingOrder.paidAmount > 0
          ? existingOrder.paidAmount
          : (existingOrder.isPaid ? existingOrder.total : 0.0);
      final currentCartTotal = _controller.cartTotal;
      final additionalDue = currentCartTotal - prevPaid;

      if (wasPaid && additionalDue > 0) {
        // Prompt cashier to collect additional payment for the added items!
        final result = await PaymentConfirmationDialog.show(
          context,
          orderNumber: editToken,
          isEditing: true,
          totalDue: additionalDue,
          customerName: custName.isNotEmpty
              ? custName
              : existingOrder.displayCustomerName,
          previousPaid: prevPaid,
          newTotal: currentCartTotal,
        );

        if (result == null) {
          // Cashier tapped "Back to Cart" - abort update and keep cart open
          return;
        }

        if (result.isMarkAsPending) {
          // Pay later / keep pending: order is updated, but additional due is unpaid!
          await _controller.punchOrUpdateOrder(
            customerName: custName.isNotEmpty ? custName : null,
            isPaid: false,
            paidAmount: prevPaid,
            paidItems: existingOrder.paidItems.isNotEmpty
                ? existingOrder.paidItems
                : existingOrder.items,
          );
          _customerNameController.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order #$editToken updated! Additional ₹${additionalDue.toStringAsFixed(0)} pending.',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } else {
          // Additional payment confirmed via selected payment method
          await _controller.punchOrUpdateOrder(
            customerName: custName.isNotEmpty ? custName : null,
            isPaid: true,
            paidAmount: currentCartTotal,
            paidItems: Map.from(_controller.cart),
            paymentMethod: result.paymentMethod,
          );
          _customerNameController.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order #$editToken updated! Additional ₹${additionalDue.toStringAsFixed(0)} paid via ${result.paymentMethod}!',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      } else if (wasPaid && additionalDue < 0) {
        // Items were removed: refund difference to customer
        await _controller.punchOrUpdateOrder(
          customerName: custName.isNotEmpty ? custName : null,
          isPaid: true,
          paidAmount: currentCartTotal,
          paidItems: Map.from(_controller.cart),
        );
        _customerNameController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order #$editToken updated! Refund ₹${(-additionalDue).toStringAsFixed(0)} to customer.',
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final outcome = await _controller.punchOrUpdateOrder(
      customerName: custName.isNotEmpty ? custName : null,
      isPaid: isEdit ? null : false,
    );

    _customerNameController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.isEdit
                ? 'Order #${outcome.token} updated!'
                : 'Order #${outcome.token} placed! Payment pending.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showConfirmPaymentDialog(StallOrder order) async {
    final due = order.hasPartialPayment ? order.remainingDue : order.total;
    final result = await PaymentConfirmationDialog.show(
      context,
      orderNumber: order.token,
      isEditing: false,
      totalDue: due,
      customerName: order.displayCustomerName,
      previousPaid: order.hasPartialPayment ? order.paidAmount : null,
      newTotal: order.total,
    );

    if (result == null || result.isMarkAsPending) return;

    await _controller.confirmPayment(
      token: order.token,
      paymentMethod: result.paymentMethod,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment confirmed for Order #${order.token} via ${result.paymentMethod}!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _editOrder(StallOrder order) {
    if (_controller.cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard Current Cart?'),
          content: Text(
            'You have items in your current cart. Editing Order #${order.token} will replace your current cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performEditOrder(order);
              },
              child: const Text('Discard & Edit'),
            ),
          ],
        ),
      );
      return;
    }
    _performEditOrder(order);
  }

  void _performEditOrder(StallOrder order) {
    final custName = _controller.startEditingOrder(order);
    _customerNameController.text = custName;
    _mobileTabController.index = 0;
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing Order #${order.token}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDeleteOrder(int token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Order #$token?'),
        content: Text('Delete Order #$token? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _controller.deleteOrder(token);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order #$token deleted.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _completeOrder(int token) {
    HapticFeedback.lightImpact();
    _controller.markOrderCompleted(token);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #$token marked completed!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleCompleteTicketItem(int token, String itemId, String itemName, int quantity) async {
    HapticFeedback.mediumImpact();
    final wasOrderCompleted = await _controller.completeOrderItem(
      token: token,
      itemId: itemId,
      quantity: quantity,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasOrderCompleted
              ? 'Order #$token completed! ($itemName x$quantity)'
              : '$itemName x$quantity done for Order #$token',
        ),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _controller.uncompleteOrderItem(
              token: token,
              itemId: itemId,
              quantity: quantity,
            );
          },
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleCompleteAllItem(String itemId, String itemName) async {
    HapticFeedback.mediumImpact();
    final completedTokens = await _controller.completeAggregatedItem(itemId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          completedTokens.isNotEmpty
              ? 'All $itemName completed! Orders ${completedTokens.map((t) => '#$t').join(', ')} finished!'
              : 'All $itemName completed!',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleToggleItemCompletion(int token, String itemId, bool complete) async {
    HapticFeedback.lightImpact();
    if (complete) {
      final wasOrderCompleted = await _controller.completeOrderItem(
        token: token,
        itemId: itemId,
      );
      if (!mounted) return;
      if (wasOrderCompleted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$token marked completed!'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                _controller.uncompleteOrderItem(token: token, itemId: itemId);
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      await _controller.uncompleteOrderItem(token: token, itemId: itemId);
    }
  }

  void _showAddOrEditItemDialog({MenuItem? existingItem}) {
    AddEditMenuItemDialog.show(
      context,
      controller: _controller,
      existingItem: existingItem,
      categories: _categories.where((c) => c != 'All').toList(),
      getCategoryColor: _getCategoryColor,
      resolvedCategoryColors: _resolvedCategoryColors,
    );
  }

  void _showItemOptionsBottomSheet(MenuItem item) {
    AddEditMenuItemDialog.showOptionsBottomSheet(
      context,
      item: item,
      controller: _controller,
      categories: _categories.where((c) => c != 'All').toList(),
      getCategoryColor: _getCategoryColor,
      resolvedCategoryColors: _resolvedCategoryColors,
    );
  }



  void _openOrderHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OrderHistoryScreen(
          storageService: _controller.storageService,
          controller: _controller,
          onOrdersChanged: () {
            _controller.loadPersistedData();
          },
        ),
      ),
    );
    _controller.loadPersistedData();
  }

  void _openCsvImport() {
    CsvImportDialog.showMenuItemsDialog(
      context,
      existingCount: _menu.length,
      onImport: (importedItems, replaceExisting) {
        _controller.setMenu(importedItems, replace: replaceExisting);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replaceExisting
                  ? 'Replaced menu with ${importedItems.length} items from CSV!'
                  : 'Imported ${importedItems.length} menu items from CSV!',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pendingOrders = _controller.activeOrders;
    final totalRevenue = _controller.orders.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );
    final totalPrepItems = _controller.combinedActiveOrders.fold<int>(
      0,
      (sum, item) => sum + item.totalQuantity,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚡ StallPOS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(
                'Orders: ${_controller.orders.length} | ₹${totalRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Order History',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _openOrderHistory,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload Menu CSV',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: _openCsvImport,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Menu Item',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _showAddOrEditItemDialog(),
          ),
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                ),
                tooltip: isDark
                    ? 'Switch to Light Theme'
                    : 'Switch to Dark Theme',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => ThemeController.instance.toggleTheme(),
              );
            },
          ),
        ],
        bottom: MediaQuery.of(context).size.width <= 900
            ? TabBar(
                controller: _mobileTabController,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.touch_app_rounded),
                    text: 'POS / Register',
                  ),
                  Tab(
                    icon: Badge(
                      label: Text('${pendingOrders.length}'),
                      isLabelVisible: pendingOrders.isNotEmpty,
                      child: const Icon(Icons.restaurant_rounded),
                    ),
                    text: 'Active Orders',
                  ),
                  Tab(
                    icon: Badge(
                      label: Text('$totalPrepItems'),
                      isLabelVisible: totalPrepItems > 0,
                      child: const Icon(Icons.inventory_2_rounded),
                    ),
                    text: 'Item Summary',
                  ),
                ],
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Large screen (Tablet / Desktop): Side-by-side view with right-side tabs
          if (constraints.maxWidth > 900) {
            return Row(
              children: [
                Expanded(flex: 5, child: _buildTakeOrderPanel()),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      TabBar(
                        controller: _desktopTabController,
                        tabs: [
                          Tab(
                            icon: Badge(
                              label: Text('${pendingOrders.length}'),
                              isLabelVisible: pendingOrders.isNotEmpty,
                              child: const Icon(Icons.receipt_long_rounded),
                            ),
                            text: 'Active Orders',
                          ),
                          Tab(
                            icon: Badge(
                              label: Text('$totalPrepItems'),
                              isLabelVisible: totalPrepItems > 0,
                              child: const Icon(Icons.inventory_2_rounded),
                            ),
                            text: 'Item Summary',
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _desktopTabController,
                          children: [
                            _buildActiveOrdersPanel(pendingOrders),
                            _buildItemSummaryPanel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // Small screen (Mobile): 3-Tab view
          return TabBarView(
            controller: _mobileTabController,
            children: [
              _buildTakeOrderPanel(),
              _buildActiveOrdersPanel(pendingOrders),
              _buildItemSummaryPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return MenuItemCard(
      item: item,
      cart: _cart,
      getCategoryColor: _getCategoryColor,
      onTap: () => _handleMenuItemTap(item),
      onLongPress: () => _showItemOptionsBottomSheet(item),
    );
  }

  Widget _buildCategoryAccordionCard(String category, List<MenuItem> items) {
    return CategoryAccordionCard(
      catName: category,
      items: items,
      isExpanded: !_collapsedCategories.contains(category),
      onToggle: () {
        setState(() {
          if (_collapsedCategories.contains(category)) {
            _collapsedCategories.remove(category);
          } else {
            _collapsedCategories.add(category);
          }
        });
      },
      getCategoryColor: _getCategoryColor,
      itemCardBuilder: (item) => _buildMenuItemCard(item),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TAKE ORDER PANEL (MENU CARDS + EXPANDABLE ACCORDIONS + CART DRAWER)
  // ---------------------------------------------------------------------------

  Widget _buildTakeOrderPanel() {
    final categories = _categories;
    final grouped = _controller.groupedMenu;

    return Column(
      children: [
        // Category Filter Bar
        if (_menu.isNotEmpty && categories.length > 1)
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = categories[i];
                final isSelected = _controller.selectedCategory == cat;
                final catColor = _getCategoryColor(cat);
                return ChoiceChip(
                  avatar: cat == 'All'
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? catColor : null,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: catColor.withAlpha(45),
                  side: BorderSide(
                    color: isSelected ? catColor : catColor.withAlpha(90),
                    width: isSelected ? 1.8 : 1,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _controller.selectCategory(cat);
                    }
                  },
                );
              },
            ),
          ),

        // Menu item list with Expandable Accordion Categories
        Expanded(
          flex: 6,
          child: _menu.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No menu items yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap + in the top bar to add your first item',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _openCsvImport,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Upload CSV Menu'),
                      ),
                    ],
                  ),
                )
              : grouped.isEmpty
              ? Center(
                  child: Text(
                    'No items in category "${_controller.selectedCategory}"',
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: grouped.entries.map((entry) {
                      return _buildCategoryAccordionCard(entry.key, entry.value);
                    }).toList(),
                  ),
                ),
        ),

        // Cart Drawer / Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active Editing Banner
              if (_controller.isEditing)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing Order #${_controller.editingOrderId}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Cancel Edit'),
                      ),
                    ],
                  ),
                ),

              // Customer Name Input
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    hintText: 'Customer Name (Optional)',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Cart Items Bar (taps to open bottomsheet)
              if (_cart.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: _showCartBottomSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Items in Cart (${_controller.cartItemCount})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _cart.entries
                                      .map((e) {
                                        final item = _controller.findItem(e.key);
                                        return '${e.value}x ${item.displayName}';
                                      })
                                      .join(', '),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: _showCartBottomSheet,
                            icon: const Icon(
                              Icons.expand_less_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'View Cart',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _clearCart,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              // Order Confirmation Action Buttons: Side-by-Side (Pay & Punch + Punch Order)
              if (!_controller.isEditing)
                Row(
                  children: [
                    // 1-Step Pay & Punch Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _cart.isNotEmpty ? () => _fireOrder(immediatePayment: true) : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(
                            Icons.payment_rounded,
                            size: 20,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _cart.isEmpty
                                  ? 'PAY & PUNCH (1-STEP)'
                                  : 'PAY & PUNCH (#${_controller.nextToken}) • ₹${_controller.cartTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Punch Order (Pay Later) Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _cart.isNotEmpty ? () => _fireOrder() : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(
                            Icons.bolt,
                            size: 22,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _cart.isEmpty
                                  ? 'TAP ITEMS TO START (#${_controller.nextToken})'
                                  : 'PUNCH ORDER (#${_controller.nextToken}) • ₹${_controller.cartTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Primary Update Button when editing
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _cart.isNotEmpty ? () => _fireOrder() : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.update_rounded,
                      size: 26,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _cart.isEmpty
                            ? 'TAP ITEMS TO UPDATE (#${_controller.editingOrderId})'
                            : 'Update Order #${_controller.editingOrderId} • ₹${_controller.cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. ACTIVE ORDERS QUEUE
  // ---------------------------------------------------------------------------

  Widget _buildActiveOrdersPanel(List<StallOrder> pendingOrders) {
    return ActiveOrdersPanel(
      controller: _controller,
      onConfirmPayment: _showConfirmPaymentDialog,
      onEditOrder: _editOrder,
      onDeleteOrder: _confirmDeleteOrder,
      onCompleteOrder: _completeOrder,
      onToggleItemCompletion: _handleToggleItemCompletion,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ITEM SUMMARY PREPARATION QUEUE
  // ---------------------------------------------------------------------------

  Widget _buildItemSummaryPanel() {
    return ItemSummaryPanel(
      controller: _controller,
      getCategoryColor: _getCategoryColor,
      onCompleteTicketItem: _handleCompleteTicketItem,
      onCompleteAllItem: _handleCompleteAllItem,
    );
  }
}

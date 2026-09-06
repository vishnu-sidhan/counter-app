import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/order_controller.dart';
import '../controllers/theme_controller.dart';
import '../data/models/stall_models.dart';
import '../data/services/stall_storage_service.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/payment_confirmation_dialog.dart';
import 'order_history_screen.dart';
import '../theme/category_colors.dart';

// Re-export models and controller for backwards compatibility
export '../data/models/stall_models.dart';
export '../controllers/order_controller.dart';

class StallPosScreen extends StatefulWidget {
  final StallStorageService? storageService;
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _controller = OrderController(
        storageService: widget.storageService ?? StallStorageService(),
      );
      _internalController = true;
      _controller.loadPersistedData();
    }
    _controller.addListener(_onControllerChanged);

    _mobileTabController = TabController(length: 3, vsync: this);
    _desktopTabController = TabController(length: 2, vsync: this);

    // Auto-refresh ticket elapsed times every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
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
    _timer?.cancel();
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
  // CART ACTIONS
  // ---------------------------------------------------------------------------

  void _addToCart(MenuItem item) {
    HapticFeedback.selectionClick();
    _controller.addToCart(item);
  }

  void _removeFromCart(String itemId) {
    _controller.removeFromCart(itemId);
  }

  void _clearCart() {
    _controller.clearCart();
    if (!_controller.isEditing) {
      _customerNameController.clear();
    }
  }

  void _cancelEdit() {
    _controller.cancelEditingOrder();
    _customerNameController.clear();
  }

  void _showCartBottomSheet() {
    if (_cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cartEntries = _cart.entries.map((e) {
              final item = _menu.firstWhere(
                (m) => m.id == e.key,
                orElse: () => MenuItem(id: e.key, name: 'Item', price: 0),
              );
              return (item: item, quantity: e.value);
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(50),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withAlpha(150),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Sheet Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cart (${_controller.cartItemCount} ${_controller.cartItemCount == 1 ? "item" : "items"})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_cart.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                _clearCart();
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Clear Cart'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Items List
                    if (cartEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.remove_shopping_cart_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your cart is empty',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: cartEntries.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 16),
                          itemBuilder: (context, i) {
                            final entry = cartEntries[i];
                            final item = entry.item;
                            final qty = entry.quantity;
                            final catColor = item.colorHex != null
                                ? Color(item.colorHex!)
                                : _getCategoryColor(item.category);
                            final itemTotal = item.price * qty;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Category Color indicator
                                Container(
                                  width: 4,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Item Name + Category in brackets
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (item.category
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: catColor.withAlpha(30),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: catColor.withAlpha(90),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                '(${item.category})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: catColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '₹${item.price.toStringAsFixed(0)} each',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Stepper: [-] [qty] [+]
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        onPressed: () {
                                          _removeFromCart(item.id);
                                          setSheetState(() {});
                                          if (_cart.isEmpty) {
                                            Navigator.pop(sheetContext);
                                          }
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        onPressed: () {
                                          _addToCart(item);
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Subtotal
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '₹${itemTotal.toStringAsFixed(0)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    if (_cart.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Total row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Payable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${_controller.cartTotal.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Checkout button inside bottomsheet
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _fireOrder();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _controller.isEditing
                                      ? Colors.orange.shade800
                                      : Colors.green.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: Icon(
                                  _controller.isEditing
                                      ? Icons.update_rounded
                                      : Icons.bolt,
                                  size: 24,
                                ),
                                label: Text(
                                  _controller.isEditing
                                      ? 'Update Order #${_controller.editingOrderId} • ₹${_controller.cartTotal.toStringAsFixed(0)}'
                                      : 'PUNCH ORDER (#${_controller.nextToken}) • ₹${_controller.cartTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS: FIRE / UPDATE, EDIT, DELETE, COMPLETE
  // ---------------------------------------------------------------------------

  Future<void> _fireOrder() async {
    if (_controller.cart.isEmpty) return;

    final isEdit = _controller.isEditing;
    final custName = _customerNameController.text.trim();

    HapticFeedback.heavyImpact();

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
    final result = await PaymentConfirmationDialog.show(
      context,
      orderNumber: order.token,
      isEditing: false,
      totalDue: order.total,
      customerName: order.displayCustomerName,
    );

    if (result == null) return;

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
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.deleteOrder(token);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #$token deleted.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _completeOrder(int token) {
    HapticFeedback.mediumImpact();
    _controller.completeOrder(token);
  }

  // ---------------------------------------------------------------------------
  // MENU ITEM MANAGEMENT DIALOGS
  // ---------------------------------------------------------------------------

  void _showAddOrEditItemDialog({MenuItem? existingItem}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '',
    );
    String selectedCat =
        existingItem?.category ??
        (_controller.selectedCategory != 'All'
            ? _controller.selectedCategory
            : 'General');
    final categoryCtrl = TextEditingController(text: selectedCat);
    int? selectedColorHex = existingItem?.colorHex;

    final existingCategories = _categories.where((c) => c != 'All').toList();
    if (!existingCategories.contains('General')) {
      existingCategories.insert(0, 'General');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final effectiveCategory = categoryCtrl.text.trim().isEmpty
              ? 'General'
              : categoryCtrl.text.trim();
          final currentEffectiveColor = selectedColorHex != null
              ? Color(selectedColorHex!)
              : _getCategoryColor(effectiveCategory);

          return AlertDialog(
            title: Text(isEditing ? 'Edit Menu Item' : 'Add Menu Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: !isEditing,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'e.g. Masala Chai, Veg Roll',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹) *',
                      hintText: 'e.g. 50',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: existingCategories.map((cat) {
                      final isCurrent =
                          categoryCtrl.text.trim().toLowerCase() ==
                          cat.trim().toLowerCase();
                      final catColor = _getCategoryColor(cat);
                      return ChoiceChip(
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(cat, style: const TextStyle(fontSize: 12)),
                        selected: isCurrent,
                        selectedColor: catColor.withAlpha(50),
                        side: BorderSide(
                          color: isCurrent ? catColor : catColor.withAlpha(80),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() {
                              categoryCtrl.text = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Or enter custom category',
                      hintText: 'e.g. Beverages, Snacks, Dessert',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Category & Item Color',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: currentEffectiveColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedColorHex == null ? 'Auto / Random' : 'Custom',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: selectedColorHex == null
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            label: const Text(
                              'Auto',
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor: selectedColorHex == null
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            onPressed: () {
                              setDialogState(() {
                                selectedColorHex = null;
                              });
                            },
                          ),
                        ),
                        ...CategoryColorHelper.palette.map((colorVal) {
                          final isSelected = selectedColorHex == colorVal;
                          final color = Color(colorVal);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedColorHex = colorVal;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color:
                                            CategoryColorHelper.getContrastingTextColor(
                                              color,
                                            ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                  var category = categoryCtrl.text.trim();
                  if (category.isEmpty) category = 'General';
                  final resolvedColor =
                      selectedColorHex ??
                      _resolvedCategoryColors[category] ??
                      CategoryColorHelper.getUniqueColor(
                        categoryName: category,
                        usedColors: _resolvedCategoryColors.values.toSet(),
                      );

                  if (name.isNotEmpty && price > 0) {
                    if (isEditing) {
                      _controller.updateMenuItem(
                        existingItem.copyWith(
                          name: name,
                          price: price,
                          category: category,
                          colorHex: resolvedColor,
                        ),
                      );
                    } else {
                      _controller.addMenuItem(
                        MenuItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          price: price,
                          category: category,
                          colorHex: resolvedColor,
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  }
                },
                child: Text(isEditing ? 'Save Changes' : 'Add Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showItemOptionsBottomSheet(MenuItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.colorHex != null
                          ? Color(item.colorHex!)
                          : _getCategoryColor(item.category),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${item.category} • ₹${item.price.toStringAsFixed(0)}'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Item Details'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddOrEditItemDialog(existingItem: item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Item',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(MenuItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu Item?'),
        content: Text(
          'Are you sure you want to delete "${item.name}" from the menu?',
        ),
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
              _controller.deleteMenuItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openOrderHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OrderHistoryScreen(
          storageService: _controller.storageService,
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'Orders: ${_controller.orders.length} | ₹${totalRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Order History',
            onPressed: _openOrderHistory,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Upload Menu CSV',
            onPressed: _openCsvImport,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Menu Item',
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

  // ---------------------------------------------------------------------------
  // 1. POS / REGISTER PANEL (MENU + EXPANDABLE CATEGORIES + CART)
  // ---------------------------------------------------------------------------

  Widget _buildMenuItemCard(MenuItem item) {
    final inCartQty = _cart[item.id] ?? 0;
    final itemColor = item.colorHex != null
        ? Color(item.colorHex!)
        : _getCategoryColor(item.category);

    return InkWell(
      key: ValueKey(item.id),
      onTap: () => _addToCart(item),
      onLongPress: () => _showItemOptionsBottomSheet(item),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: inCartQty > 0
              ? itemColor.withAlpha(45)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0 ? itemColor : itemColor.withAlpha(65),
            width: inCartQty > 0 ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: itemColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${item.name} (${item.category})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: inCartQty > 0
                          ? itemColor
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (inCartQty > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: itemColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$inCartQty',
                        style: TextStyle(
                          color: CategoryColorHelper.getContrastingTextColor(
                            itemColor,
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

        // Menu item list with Expandable Accordion Categories (Requirement 4)
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
                    children: grouped.entries.map((entry) {
                      final catName = entry.key;
                      final items = entry.value;
                      final catColor = _getCategoryColor(catName);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: catColor.withAlpha(60),
                            width: 1.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          key: PageStorageKey('pos_category_$catName'),
                          initiallyExpanded: true,
                          maintainState: true,
                          leading: Container(
                            width: 6,
                            height: 24,
                            decoration: BoxDecoration(
                              color: catColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          title: Text(
                            catName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withAlpha(35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: catColor.withAlpha(90)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${items.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  items.length == 1 ? 'item' : 'items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            4,
                            12,
                            12,
                          ),
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const double maxExtent = 165.0;
                                const double spacing = 12.0;
                                const double childAspectRatio = 0.98;
                                int crossAxisCount =
                                    (constraints.maxWidth /
                                            (maxExtent + spacing))
                                        .ceil();
                                crossAxisCount = crossAxisCount < 1
                                    ? 1
                                    : crossAxisCount;
                                final double usableWidth = math.max(
                                  0.0,
                                  constraints.maxWidth -
                                      spacing * (crossAxisCount - 1),
                                );
                                final double childWidth =
                                    usableWidth / crossAxisCount;
                                final double childHeight =
                                    childWidth / childAspectRatio;

                                return Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: items.map((menuItem) {
                                    return SizedBox(
                                      width: childWidth,
                                      height: childHeight,
                                      child: _buildMenuItemCard(menuItem),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      );
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
              // Active Editing Banner (Requirement 1)
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

              // Customer Name Input (Requirement 2)
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
                                        final item = _menu.firstWhere(
                                          (m) => m.id == e.key,
                                          orElse: () => MenuItem(
                                            id: e.key,
                                            name: 'Item',
                                            price: 0,
                                          ),
                                        );
                                        final catSuffix =
                                            item.category.trim().isNotEmpty
                                            ? ' (${item.category})'
                                            : '';
                                        return '${e.value}x ${item.name}$catSuffix';
                                      })
                                      .join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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

              // Checkout Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _cart.isNotEmpty ? _fireOrder : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _controller.isEditing
                        ? Colors.orange.shade800
                        : Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _controller.isEditing ? Icons.update_rounded : Icons.bolt,
                    size: 26,
                  ),
                  label: Text(
                    _cart.isEmpty
                        ? (_controller.isEditing
                              ? 'TAP ITEMS TO UPDATE (#${_controller.editingOrderId})'
                              : 'TAP ITEMS TO START (#${_controller.nextToken})')
                        : (_controller.isEditing
                              ? 'Update Order #${_controller.editingOrderId} • ₹${_controller.cartTotal.toStringAsFixed(0)}'
                              : 'PUNCH ORDER (#${_controller.nextToken}) • ₹${_controller.cartTotal.toStringAsFixed(0)}'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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
  // 2. ACTIVE ORDERS QUEUE (INDIVIDUAL TICKETS + EDIT + DELETE + DONE)
  // ---------------------------------------------------------------------------

  Widget _buildActiveOrdersPanel(List<StallOrder> pendingOrders) {
    final confirmed = _controller.confirmedActiveOrders;
    final toConfirm = _controller.toConfirmPaymentOrders;

    if (confirmed.isEmpty && toConfirm.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 12),
            Text(
              'All caught up! No pending orders.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // -------------------------------------------------------------
        // SECTION 1: CONFIRMED PAYMENT ORDERS (Above / Top)
        // -------------------------------------------------------------
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Confirmed Payment Orders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${confirmed.length}',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (confirmed.isEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  'No confirmed orders awaiting preparation',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          )
        else
          ...confirmed.map(
            (order) => _buildOrderCard(order, isConfirmedPayment: true),
          ),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(thickness: 1.5),
        ),

        // -------------------------------------------------------------
        // SECTION 2: TO CONFIRM PAYMENT ORDERS (Below / Bottom)
        // -------------------------------------------------------------
        Row(
          children: [
            const Icon(
              Icons.pending_actions_rounded,
              color: Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'To Confirm Payment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${toConfirm.length}',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (toConfirm.isEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  'No orders pending payment',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          )
        else
          ...toConfirm.map(
            (order) => _buildOrderCard(order, isConfirmedPayment: false),
          ),
      ],
    );
  }

  Widget _buildOrderCard(StallOrder order, {required bool isConfirmedPayment}) {
    final now = DateTime.now();
    final diffMinutes = now.difference(order.timestamp).inMinutes;

    Color cardBorderColor = Colors.blue.shade700;
    if (diffMinutes >= 7) {
      cardBorderColor = Colors.red.shade700;
    } else if (diffMinutes >= 3) {
      cardBorderColor = Colors.orange.shade800;
    }

    final itemsWithCategory = _controller.getOrderItemsWithCategory(order);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isConfirmedPayment ? cardBorderColor : Colors.orange.shade400,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Token, Customer Name, Payment Status Badge, Total
            Row(
              children: [
                // Token Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isConfirmedPayment
                        ? cardBorderColor
                        : Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${order.token}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Customer Name & Payment Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            order.customerName != null &&
                                    order.customerName!.trim().isNotEmpty
                                ? Icons.person
                                : Icons.person_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              order.displayCustomerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (isConfirmedPayment)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Paid • ${order.paymentMethod ?? 'Cash'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade900,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Payment Pending',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Total amount
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Vertical list of items with categories (one below the other)
            if (itemsWithCategory.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  children: itemsWithCategory.map((item) {
                    final catColor = item.colorHex != null
                        ? Color(item.colorHex!)
                        : _getCategoryColor(item.category);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          // Quantity Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Item Name & Category next to each other
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catColor.withAlpha(35),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: catColor.withAlpha(120),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              )
            else
              Text(
                order.itemsSummary,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8),

            // Footer Row: Elapsed time + Actions
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  diffMinutes == 0 ? 'Just now' : '$diffMinutes min ago',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: diffMinutes >= 3 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // If payment pending: Prominent "Confirm Payment" button
                    if (!isConfirmedPayment) ...[
                      FilledButton.icon(
                        key: ValueKey('confirm_payment_btn_${order.token}'),
                        onPressed: () => _showConfirmPaymentDialog(order),
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text(
                          'Confirm Payment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    // Edit Button
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Order',
                      onPressed: () => _editOrder(order),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),

                    // Delete Button
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: 'Delete Order',
                      onPressed: () => _confirmDeleteOrder(order.token),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),

                    // If confirmed payment: Done Button
                    if (isConfirmedPayment) ...[
                      const SizedBox(width: 6),
                      FilledButton.tonal(
                        onPressed: () => _completeOrder(order.token),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          foregroundColor: Colors.green.shade900,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        child: const Text(
                          '✓ Done',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. COMBINED ORDERS VIEW / CONSOLIDATED ITEMS TAB (Requirement 5)
  // ---------------------------------------------------------------------------

  Widget _buildItemSummaryPanel() {
    final combined = _controller.combinedActiveOrders;

    if (combined.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No active orders in queue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Aggregated items to prepare across all tickets will appear here',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: combined.length,
      itemBuilder: (context, index) {
        final item = combined[index];
        final color = item.colorHex != null
            ? Color(item.colorHex!)
            : _getCategoryColor(item.category);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withAlpha(90), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category Color Strip
                Container(
                  width: 5,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),

                // Item Details & Order Tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withAlpha(70)),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ticket tags: e.g. Orders: #101 (3), #104 (2)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Orders: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          ...item.tickets.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                '#${t.token} (${t.quantity})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Large Badge with Total Quantity to Prepare: e.g. x8
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(70),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'x${item.totalQuantity}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: CategoryColorHelper.getContrastingTextColor(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

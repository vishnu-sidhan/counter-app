import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/stall_models.dart';
import '../data/services/stall_storage_service.dart';
import '../widgets/csv_import_dialog.dart';
import 'order_history_screen.dart';
import '../theme/category_colors.dart';

// Re-export models for backwards compatibility
export '../data/models/stall_models.dart';

class StallPosScreen extends StatefulWidget {
  final StallStorageService? storageService;

  const StallPosScreen({
    super.key,
    this.storageService,
  });

  @override
  State<StallPosScreen> createState() => _StallPosScreenState();
}

class _StallPosScreenState extends State<StallPosScreen>
    with SingleTickerProviderStateMixin {
  late final StallStorageService _storageService;
  late TabController _tabController;
  Timer? _timer;

  // State
  List<MenuItem> _menu = [];
  String _selectedCategory = 'All';
  final Map<String, int> _cart = {}; // menuItem.id -> quantity
  List<StallOrder> _orders = [];
  int _nextToken = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? StallStorageService();
    _tabController = TabController(length: 2, vsync: this);
    _loadPersistedData();
    // Auto-refresh ticket elapsed times every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE
  // ---------------------------------------------------------------------------

  Future<void> _loadPersistedData() async {
    final menu = await _storageService.loadMenu();
    final orders = await _storageService.loadOrders();
    final nextToken = await _storageService.loadNextToken();

    if (mounted) {
      setState(() {
        _menu = menu;
        _orders = orders;
        _nextToken = nextToken;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveState() async {
    await _storageService.saveMenu(_menu);
    await _storageService.saveOrders(_orders);
    await _storageService.saveNextToken(_nextToken);
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES & FILTERING
  // ---------------------------------------------------------------------------

  List<String> get _categories {
    final set = <String>{'All'};
    for (final item in _menu) {
      if (item.category.trim().isNotEmpty) {
        set.add(item.category.trim());
      }
    }
    return set.toList();
  }

  /// Computes a guaranteed unique, visually distinct color for every category in the menu.
  /// No two categories will ever share the same color or look alike.
  Map<String, int> get _resolvedCategoryColors {
    final result = <String, int>{};
    final usedColors = <int>{};
    final allCategories = _categories.where((c) => c != 'All').toList();

    // 1. First pass: Assign explicit colors from menu items if not already claimed
    for (final cat in allCategories) {
      final normalized = cat.trim().toLowerCase();
      for (final m in _menu) {
        if (m.category.trim().toLowerCase() == normalized && m.colorHex != null) {
          if (!usedColors.contains(m.colorHex!)) {
            result[cat] = m.colorHex!;
            usedColors.add(m.colorHex!);
            break;
          }
        }
      }
    }

    // 2. Second pass: For categories without colors or on collision, allocate a guaranteed unique color
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
    final hex = map[category] ??
        CategoryColorHelper.getUniqueColor(
          categoryName: category,
          usedColors: map.values.toSet(),
        );
    return Color(hex);
  }

  List<MenuItem> get _filteredMenu {
    if (_selectedCategory == 'All') return _menu;
    return _menu.where((m) => m.category == _selectedCategory).toList();
  }

  Map<String, List<MenuItem>> get _groupedMenu {
    final map = <String, List<MenuItem>>{};
    final items = _filteredMenu;
    for (final item in items) {
      final cat =
          item.category.trim().isEmpty ? 'General' : item.category.trim();
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // ORDER ACTIONS
  // ---------------------------------------------------------------------------

  void _addToCart(MenuItem item) {
    HapticFeedback.selectionClick();
    setState(() {
      _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]! > 1) {
          _cart[itemId] = _cart[itemId]! - 1;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  double get _cartTotal {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _menu.firstWhere(
        (m) => m.id == itemId,
        orElse: () => const MenuItem(id: '', name: '', price: 0),
      );
      total += item.price * qty;
    });
    return total;
  }

  void _fireOrder() {
    if (_cart.isEmpty) return;

    HapticFeedback.heavyImpact();

    final summaryParts = <String>[];
    _cart.forEach((itemId, qty) {
      final item = _menu.firstWhere((m) => m.id == itemId);
      summaryParts.add('${qty}x ${item.name}');
    });

    final newOrder = StallOrder(
      token: _nextToken,
      itemsSummary: summaryParts.join(', '),
      total: _cartTotal,
      timestamp: DateTime.now(),
    );

    setState(() {
      _orders.add(newOrder);
      _nextToken++;
      _cart.clear();
    });

    _saveState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${newOrder.token} sent to kitchen!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _completeOrder(int token) {
    HapticFeedback.mediumImpact();
    setState(() {
      final idx = _orders.indexWhere((o) => o.token == token);
      if (idx != -1) {
        _orders[idx].isCompleted = true;
        _orders[idx].completedAt = DateTime.now();
      }
    });
    _saveState();
  }

  // ---------------------------------------------------------------------------
  // MENU ITEM MANAGEMENT (ADD / EDIT / DELETE)
  // ---------------------------------------------------------------------------

  void _showAddOrEditItemDialog({MenuItem? existingItem}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '',
    );
    String selectedCat = existingItem?.category ??
        (_selectedCategory != 'All' ? _selectedCategory : 'General');
    final categoryCtrl = TextEditingController(text: selectedCat);
    int? selectedColorHex = existingItem?.colorHex;

    // Existing categories (excluding 'All')
    final existingCategories = _categories.where((c) => c != 'All').toList();
    if (!existingCategories.contains('General')) {
      existingCategories.insert(0, 'General');
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final effectiveCategory = categoryCtrl.text.trim().isEmpty ? 'General' : categoryCtrl.text.trim();
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  // Quick category suggestions chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: existingCategories.map((cat) {
                      final isCurrent = categoryCtrl.text.trim().toLowerCase() ==
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
                        selectedColor: catColor.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: isCurrent ? catColor : catColor.withValues(alpha: 0.3),
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                            label: const Text('Auto', style: TextStyle(fontSize: 11)),
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
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: CategoryColorHelper.getContrastingTextColor(color),
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
                  final resolvedColor = selectedColorHex ??
                      _resolvedCategoryColors[category] ??
                      CategoryColorHelper.getUniqueColor(
                        categoryName: category,
                        usedColors: _resolvedCategoryColors.values.toSet(),
                      );

                  if (name.isNotEmpty && price > 0) {
                    setState(() {
                      if (isEditing) {
                        final idx = _menu.indexWhere((m) => m.id == existingItem.id);
                        if (idx != -1) {
                          _menu[idx] = existingItem.copyWith(
                            name: name,
                            price: price,
                            category: category,
                            colorHex: resolvedColor,
                          );
                        }
                      } else {
                        _menu.add(MenuItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          price: price,
                          category: category,
                          colorHex: resolvedColor,
                        ));
                      }
                    });
                    _saveState();
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  Text(
                    '${item.category} • ₹${item.price.toStringAsFixed(0)}',
                  ),
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
        content: Text('Are you sure you want to delete "${item.name}" from the menu?'),
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
              setState(() {
                _menu.removeWhere((m) => m.id == item.id);
                _cart.remove(item.id);
                if (_selectedCategory != 'All' &&
                    !_menu.any((m) => m.category == _selectedCategory)) {
                  _selectedCategory = 'All';
                }
              });
              _saveState();
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
          storageService: _storageService,
          onOrdersChanged: () {
            _loadPersistedData();
          },
        ),
      ),
    );
    _loadPersistedData();
  }

  void _openCsvImport() {
    CsvImportDialog.showMenuItemsDialog(
      context,
      existingCount: _menu.length,
      onImport: (importedItems, replaceExisting) {
        setState(() {
          if (replaceExisting) {
            _menu = List.from(importedItems);
            _cart.clear();
            _selectedCategory = 'All';
          } else {
            _menu.addAll(importedItems);
          }
        });
        _saveState();
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pendingOrders = _orders.where((o) => !o.isCompleted).toList();
    final totalRevenue = _orders.fold<double>(0, (sum, o) => sum + o.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ StallPOS', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'Orders: ${_orders.length} | ₹${totalRevenue.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
        ],
        bottom: MediaQuery.of(context).size.width <= 700
            ? TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(icon: Icon(Icons.touch_app), text: 'New Order'),
                  Tab(
                    icon: Badge(
                      label: Text('${pendingOrders.length}'),
                      isLabelVisible: pendingOrders.isNotEmpty,
                      child: const Icon(Icons.restaurant),
                    ),
                    text: 'FIFO Kitchen Queue',
                  ),
                ],
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Large screen (Tablet / Desktop): Side-by-side view
          if (constraints.maxWidth > 700) {
            return Row(
              children: [
                Expanded(flex: 5, child: _buildTakeOrderPanel()),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: _buildKitchenQueuePanel(pendingOrders)),
              ],
            );
          }

          // Small screen (Mobile): Tabbed view
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTakeOrderPanel(),
              _buildKitchenQueuePanel(pendingOrders),
            ],
          );
        },
      ),
    );
  }

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
              ? itemColor.withValues(alpha: 0.18)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCartQty > 0
                ? itemColor
                : itemColor.withValues(alpha: 0.25),
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
                    item.name,
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: itemColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$inCartQty',
                        style: TextStyle(
                          color: CategoryColorHelper.getContrastingTextColor(itemColor),
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

    return Column(
      children: [
        // Category Filter Bar (shown when there are categories)
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
                final isSelected = _selectedCategory == cat;
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? catColor : null,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: catColor.withValues(alpha: 0.18),
                  side: BorderSide(
                    color: isSelected
                        ? catColor
                        : catColor.withValues(alpha: 0.35),
                    width: isSelected ? 1.8 : 1,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              },
            ),
          ),

        // Menu item grid
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
                            fontSize: 18, fontWeight: FontWeight.bold),
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
              : _groupedMenu.isEmpty
                  ? Center(
                      child: Text(
                        'No items in category "$_selectedCategory"',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        for (final entry in _groupedMenu.entries) ...[
                          // Category Heading
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(entry.key),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(entry.key)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getCategoryColor(entry.key)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '${entry.value.length}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _getCategoryColor(entry.key),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Category Items Grid
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 165,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.98,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) =>
                                    _buildMenuItemCard(entry.value[i]),
                                childCount: entry.value.length,
                              ),
                            ),
                          ),
                        ],
                      ],
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
              if (_cart.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items in Cart (${_cart.values.fold(0, (a, b) => a + b)})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton(onPressed: _clearCart, child: const Text('Clear')),
                  ],
                ),
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _cart.entries.map((e) {
                      final item = _menu.firstWhere((m) => m.id == e.key);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text('${e.value}x ${item.name}'),
                          onDeleted: () => _removeFromCart(item.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _cart.isNotEmpty ? _fireOrder : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bolt, size: 28),
                  label: Text(
                    _cart.isEmpty
                        ? 'TAP ITEMS TO START (#$_nextToken)'
                        : 'PUNCH ORDER (#$_nextToken) • ₹${_cartTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
  // 2. FIFO KITCHEN QUEUE
  // ---------------------------------------------------------------------------

  Widget _buildKitchenQueuePanel(List<StallOrder> pendingOrders) {
    if (pendingOrders.isEmpty) {
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

    final now = DateTime.now();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pendingOrders.length,
      itemBuilder: (context, index) {
        final order = pendingOrders[index]; // Index 0 is always oldest (FIFO)
        final diffMinutes = now.difference(order.timestamp).inMinutes;

        // Visual alert for aging tickets
        Color cardColor = Colors.blue.shade700;
        if (diffMinutes >= 7) {
          cardColor = Colors.red.shade700;
        } else if (diffMinutes >= 3) {
          cardColor = Colors.orange.shade800;
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: cardColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Huge Token Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${order.token}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Order Content & Age
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.itemsSummary,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        diffMinutes == 0 ? 'Just now' : '$diffMinutes min ago',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              diffMinutes >= 3 ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Complete Order Button
                FilledButton.tonal(
                  onPressed: () => _completeOrder(order.token),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade900,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: const Text('✓ Done',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

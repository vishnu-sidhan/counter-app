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
  final Set<String> _collapsedCategories = <String>{};
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
    final isAddon = item.effectiveIsAddon;
    final hasNameVariants = item.hasSlashNameVariants;
    final nameVariants = item.slashNameVariants;
    final hasCategoryVariants = item.hasSlashCategoryVariants;
    final categoryVariants = item.slashCategoryVariants;
    final baseItems = isAddon
        ? _controller.cartBaseItems.where((b) {
            if (hasNameVariants) {
              return nameVariants.any((v) =>
                  _controller.getAddonItemCount(b.id, item.id, resolvedAddonName: v) <
                  OrderController.maxPerAddonItem);
            }
            return _controller.getAddonItemCount(b.id, item.id) <
                OrderController.maxPerAddonItem;
          }).toList()
        : <MenuItem>[];

    // Add-on state: quantity stepper or multi-variant quantities
    int singleAddonQty = 1;
    final Map<String, int> variantQuantities = {
      for (final v in nameVariants) v: (v == nameVariants.first ? 1 : 0),
    };
    MenuItem? selectedBaseItem = baseItems.isNotEmpty ? baseItems.first : null;

    // Regular item selection state
    String selectedName = nameVariants.isNotEmpty ? nameVariants.first : item.name;
    String selectedCategory = categoryVariants.isNotEmpty ? categoryVariants.first : item.category;

    final itemColor = item.colorHex != null
        ? Color(item.colorHex!)
        : _getCategoryColor(item.category);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final target = selectedBaseItem ?? (baseItems.isNotEmpty ? baseItems.first : null);
            final existingSingleAddonCount = target != null
                ? _controller.getAddonItemCount(target.id, item.id)
                : 0;
            final maxAllowedForSingleAddon = (OrderController.maxPerAddonItem - existingSingleAddonCount)
                .clamp(0, OrderController.maxPerAddonItem);

            // Calculate total add-on count and cost for dynamic preview
            int totalAddonCount = 0;
            double totalAddonPrice = 0.0;
            String addonSummaryStr = '';

            if (isAddon) {
              if (hasNameVariants) {
                totalAddonCount = variantQuantities.values.fold(0, (a, b) => a + b);
                totalAddonPrice = totalAddonCount * item.price;
                final parts = <String>[];
                variantQuantities.forEach((v, q) {
                  if (q > 0) parts.add(q > 1 ? '${q}x $v' : v);
                });
                addonSummaryStr = parts.map((p) => '[$p]').join(' ');
              } else {
                totalAddonCount = singleAddonQty;
                totalAddonPrice = singleAddonQty * item.price;
                addonSummaryStr = singleAddonQty > 1
                    ? '[${singleAddonQty}x ${item.name}]'
                    : '[${item.name}]';
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isAddon
                          ? 'Customize Extra'
                          : (hasCategoryVariants && !hasNameVariants
                              ? 'Select Category'
                              : 'Select Option'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAddon
                          ? '${item.displayName} • +₹${item.price.toStringAsFixed(0)} each'
                          : '${item.displayName} • ₹${item.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. If Add-on with slash variants: multi-variant quantity steppers
                            if (isAddon && hasNameVariants) ...[
                              Text(
                                'CHOOSE EXTRAS & QUANTITIES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                final qty = variantQuantities[variant] ?? 0;
                                final existingForVariant = target != null
                                    ? _controller.getAddonItemCount(target.id, item.id, resolvedAddonName: variant)
                                    : 0;
                                final maxForVariant = (OrderController.maxPerAddonItem - existingForVariant)
                                    .clamp(0, OrderController.maxPerAddonItem);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: qty > 0
                                        ? itemColor.withAlpha(25)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: qty > 0 ? itemColor : Theme.of(context).colorScheme.outlineVariant,
                                      width: qty > 0 ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              variant,
                                              style: TextStyle(
                                                fontWeight: qty > 0 ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '+₹${item.price.toStringAsFixed(0)} each',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Quantity Stepper: [-] [qty] [+]
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: qty > 0
                                                  ? () {
                                                      setModalState(() {
                                                        variantQuantities[variant] = qty - 1;
                                                      });
                                                      HapticFeedback.selectionClick();
                                                    }
                                                  : null,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text(
                                                '$qty',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: qty > 0 ? itemColor : null,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              onPressed: qty < maxForVariant
                                                  ? () {
                                                      setModalState(() {
                                                        variantQuantities[variant] = qty + 1;
                                                      });
                                                      HapticFeedback.selectionClick();
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 14),
                            ],

                            // 2. If Add-on without slash: single quantity stepper
                            if (isAddon && !hasNameVariants) ...[
                              Text(
                                'SELECT QUANTITY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: itemColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: itemColor, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            '+₹${item.price.toStringAsFixed(0)} each',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: singleAddonQty > 1
                                                ? () {
                                                    setModalState(() {
                                                      singleAddonQty--;
                                                    });
                                                    HapticFeedback.selectionClick();
                                                  }
                                                : null,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '$singleAddonQty',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: itemColor,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            onPressed: singleAddonQty < maxAllowedForSingleAddon
                                                ? () {
                                                    setModalState(() {
                                                      singleAddonQty++;
                                                    });
                                                    HapticFeedback.selectionClick();
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            // 3. Link to Base Item section (for Add-ons)
                            if (isAddon && baseItems.isNotEmpty) ...[
                              Text(
                                baseItems.length > 1 ? 'LINK TO MAIN ITEM' : 'TARGET MAIN ITEM',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...baseItems.map((baseItem) {
                                final isSelected = target?.id == baseItem.id;
                                final inCartCount = _cart[baseItem.id] ?? 1;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        selectedBaseItem = baseItem;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withAlpha(25)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? itemColor : Theme.of(context).colorScheme.outlineVariant,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: isSelected ? itemColor : Theme.of(context).colorScheme.outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  baseItem.displayName,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  '$inCartCount in cart • ₹${baseItem.price.toStringAsFixed(0)} each',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],

                            // 4. Regular item with category variants ONLY (e.g. category 'Rice / Noodles', name 'Fried Rice')
                            if (!isAddon && hasCategoryVariants && !hasNameVariants) ...[
                              Text(
                                'SELECT CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...categoryVariants.map((cat) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('cat_choice_$cat'),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      HapticFeedback.selectionClick();
                                      _controller.addCustomizedItemToCart(
                                        baseItem: item,
                                        resolvedCategory: cat,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: itemColor.withAlpha(60),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.restaurant_menu,
                                            color: itemColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              cat,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '₹${item.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: itemColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],

                            // 5. Regular item with name variants ONLY (e.g. Fried Rice / Hakka Noodles with single category)
                            if (!isAddon && hasNameVariants && !hasCategoryVariants) ...[
                              Text(
                                'SELECT ITEM OPTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('name_choice_$variant'),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      HapticFeedback.selectionClick();
                                      _controller.addCustomizedItemToCart(
                                        baseItem: item,
                                        resolvedName: variant,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: itemColor.withAlpha(60),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.radio_button_off,
                                            color: itemColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              variant,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '₹${item.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: itemColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],

                            // 6. Regular item with BOTH name and category variants
                            if (!isAddon && hasNameVariants && hasCategoryVariants) ...[
                              Text(
                                'SELECT ITEM OPTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...nameVariants.map((variant) {
                                final isSelected = selectedName == variant;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('both_name_$variant'),
                                    onTap: () {
                                      setModalState(() {
                                        selectedName = variant;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withAlpha(25)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? itemColor : itemColor.withAlpha(60),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: isSelected ? itemColor : Theme.of(context).colorScheme.outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              variant,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 14),
                              Text(
                                'SELECT CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...categoryVariants.map((cat) {
                                final isSelected = selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    key: ValueKey('both_cat_$cat'),
                                    onTap: () {
                                      setModalState(() {
                                        selectedCategory = cat;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? itemColor.withAlpha(25)
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? itemColor : itemColor.withAlpha(60),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                            color: isSelected ? itemColor : Theme.of(context).colorScheme.outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              cat,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Confirmation button for regular items with both name & category variants
                    if (!isAddon && hasNameVariants && hasCategoryVariants) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const ValueKey('confirm_add_both_variants'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          HapticFeedback.selectionClick();
                          _controller.addCustomizedItemToCart(
                            baseItem: item,
                            resolvedName: selectedName,
                            resolvedCategory: selectedCategory,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: itemColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Add $selectedName ($selectedCategory) • ₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],

                    // Confirmation button for Add-ons
                    if (isAddon) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: totalAddonCount > 0 && target != null
                            ? () {
                                Navigator.pop(sheetContext);
                                HapticFeedback.selectionClick();
                                if (hasNameVariants) {
                                  final listToAdd = <({MenuItem addon, String? resolvedName, int quantity})>[];
                                  variantQuantities.forEach((v, q) {
                                    if (q > 0) {
                                      listToAdd.add((addon: item, resolvedName: v, quantity: q));
                                    }
                                  });
                                  _controller.addMultipleAddonsToCart(
                                    targetCartItemId: target.id,
                                    addons: listToAdd,
                                  );
                                } else {
                                  _controller.addAddonToCart(
                                    targetCartItemId: target.id,
                                    addon: item,
                                    quantity: singleAddonQty,
                                  );
                                }
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $addonSummaryStr to ${target.displayName}'),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: itemColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          target != null
                              ? 'Add $addonSummaryStr to ${target.displayName} • +₹${totalAddonPrice.toStringAsFixed(0)}'
                              : 'Select a main item',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
              final item = _controller.findItem(e.key);
              final breakdown = _controller.getCartItemBreakdown(e.key);
              return (item: item, quantity: e.value, breakdown: breakdown);
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
                            final breakdown = entry.breakdown;
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
                                  height: breakdown != null ? 54 : 38,
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
                                      Text(
                                        item.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
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
                                      if (breakdown != null) ...[
                                        const SizedBox(height: 3),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withAlpha(60),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withAlpha(80),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.call_split_rounded,
                                                    size: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Split: Item ₹${breakdown.basePrice.toStringAsFixed(0)} + Add-on${breakdown.addonDetails.length > 1 || breakdown.addonDetails.any((d) => d.count > 1) ? "s" : ""} ₹${breakdown.addonsPrice.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (breakdown.addonDetails.isNotEmpty) ...[
                                                const SizedBox(height: 1),
                                                Text(
                                                  breakdown.addonDetails.map((d) {
                                                    final prefix = d.count > 1 ? '${d.count}x ' : '';
                                                    return '$prefix${d.name} (+₹${d.totalPrice.toStringAsFixed(0)})';
                                                  }).join(', '),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                              if (qty > 1) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Total ($qty qty): Item ₹${(breakdown.basePrice * qty).toStringAsFixed(0)} + Add-ons ₹${(breakdown.addonsPrice * qty).toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .outline,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (_controller.menu.any((m) => m.effectiveIsAddon)) ...[
                                        const SizedBox(height: 4),
                                        if (!_controller.canAddAnyAddon(item.id))
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  size: 13,
                                                  color: Theme.of(context).colorScheme.outline,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Max Extras (2/2)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context).colorScheme.outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          InkWell(
                                            onTap: () {
                                              _showAddonsForCartItemModal(item.id, () => setSheetState(() {}));
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.primary.withAlpha(100),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add_circle_outline,
                                                    size: 13,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '+ Extras / Add-on',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
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
                                          _controller.incrementCartItem(item.id);
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
                            // Optional breakdown if cart contains any add-ons
                            if (_controller.cartAddonsTotal > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Items Subtotal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '₹${_controller.cartBaseItemsTotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Add-ons Subtotal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '+₹${_controller.cartAddonsTotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                            ],

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

  void _showAddonsForCartItemModal(String cartItemId, [VoidCallback? onUpdated]) {
    final cartItem = _controller.findItem(cartItemId);
    final availableAddons =
        _controller.menu.where((m) => m.effectiveIsAddon).toList();
    if (availableAddons.isEmpty) return;

    if (!_controller.canAddAnyAddon(cartItemId)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 2 per add-on already reached for this item.'),
          backgroundColor: Colors.deepOrange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final Map<String, int> selectedQuantities = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            double totalAdded = 0.0;
            int totalCount = 0;
            final parts = <String>[];

            for (final addon in availableAddons) {
              if (addon.hasSlashNameVariants) {
                for (final v in addon.slashNameVariants) {
                  final key = '${addon.id}_var_$v';
                  final qty = selectedQuantities[key] ?? 0;
                  if (qty > 0) {
                    totalCount += qty;
                    totalAdded += qty * addon.price;
                    parts.add(qty > 1 ? '${qty}x $v' : v);
                  }
                }
              } else {
                final qty = selectedQuantities[addon.id] ?? 0;
                if (qty > 0) {
                  totalCount += qty;
                  totalAdded += qty * addon.price;
                  parts.add(qty > 1 ? '${qty}x ${addon.name}' : addon.name);
                }
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Add Extras / Add-ons',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For: ${cartItem.displayName} • Max 2 per add-on',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final addon in availableAddons) ...[
                            if (addon.hasSlashNameVariants)
                              for (final v in addon.slashNameVariants) ...[
                                () {
                                  final existingCount = _controller.getAddonItemCount(
                                    cartItemId,
                                    addon.id,
                                    resolvedAddonName: v,
                                  );
                                  final remainingForVariant = (OrderController.maxPerAddonItem - existingCount)
                                      .clamp(0, OrderController.maxPerAddonItem);
                                  final currentQty = selectedQuantities['${addon.id}_var_$v'] ?? 0;
                                  return _buildAddonQuantityRow(
                                    title: v,
                                    price: addon.price,
                                    qty: currentQty,
                                    canIncrement: currentQty < remainingForVariant,
                                    subtitle: remainingForVariant == 0
                                        ? '+₹${addon.price.toStringAsFixed(0)} each • Max reached'
                                        : (existingCount > 0 ? '+₹${addon.price.toStringAsFixed(0)} each ($existingCount added)' : null),
                                    onChanged: (q) {
                                      setModalState(() {
                                        selectedQuantities['${addon.id}_var_$v'] = q;
                                      });
                                    },
                                  );
                                }(),
                              ]
                            else ...[
                              () {
                                final existingCount = _controller.getAddonItemCount(
                                  cartItemId,
                                  addon.id,
                                );
                                final remainingForAddon = (OrderController.maxPerAddonItem - existingCount)
                                    .clamp(0, OrderController.maxPerAddonItem);
                                final currentQty = selectedQuantities[addon.id] ?? 0;
                                return _buildAddonQuantityRow(
                                  title: addon.name,
                                  price: addon.price,
                                  qty: currentQty,
                                  canIncrement: currentQty < remainingForAddon,
                                  subtitle: remainingForAddon == 0
                                      ? '+₹${addon.price.toStringAsFixed(0)} each • Max reached'
                                      : (existingCount > 0 ? '+₹${addon.price.toStringAsFixed(0)} each ($existingCount added)' : null),
                                  onChanged: (q) {
                                    setModalState(() {
                                      selectedQuantities[addon.id] = q;
                                    });
                                  },
                                );
                              }(),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: totalCount > 0
                          ? () {
                              Navigator.pop(ctx);
                              HapticFeedback.selectionClick();
                              final listToAdd = <
                                  ({
                                    MenuItem addon,
                                    String? resolvedName,
                                    int quantity
                                  })>[];
                              for (final addon in availableAddons) {
                                if (addon.hasSlashNameVariants) {
                                  for (final v in addon.slashNameVariants) {
                                    final q = selectedQuantities[
                                            '${addon.id}_var_$v'] ??
                                        0;
                                    if (q > 0) {
                                      listToAdd.add((
                                        addon: addon,
                                        resolvedName: v,
                                        quantity: q
                                      ));
                                    }
                                  }
                                } else {
                                  final q = selectedQuantities[addon.id] ?? 0;
                                  if (q > 0) {
                                    listToAdd.add((
                                      addon: addon,
                                      resolvedName: null,
                                      quantity: q
                                    ));
                                  }
                                }
                              }
                              _controller.addMultipleAddonsToCart(
                                targetCartItemId: cartItemId,
                                addons: listToAdd,
                              );
                              onUpdated?.call();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Added ${parts.map((p) => '[$p]').join(' ')} to ${cartItem.displayName}'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        totalCount > 0
                            ? 'Add ${parts.map((p) => '[$p]').join(' ')} • +₹${totalAdded.toStringAsFixed(0)}'
                            : 'Select extras to add (max 2 each)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddonQuantityRow({
    required String title,
    required double price,
    required int qty,
    required ValueChanged<int> onChanged,
    bool canIncrement = true,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: qty > 0
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qty > 0
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: qty > 0 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: qty > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle ?? '+₹${price.toStringAsFixed(0)} each',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '$qty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color:
                          qty > 0 ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: canIncrement ? () => onChanged(qty + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
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
    bool isAddon = existingItem?.isAddon ?? false;

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
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Mark as Add-on',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Must be linked to another item; cannot be added alone',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: isAddon,
                    onChanged: (val) {
                      setDialogState(() {
                        isAddon = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
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
                          isAddon: isAddon,
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
                          isAddon: isAddon,
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
                item.displayName,
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
          'Are you sure you want to delete "${item.displayName}" from the menu?',
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

  // ---------------------------------------------------------------------------
  // 1. POS / REGISTER PANEL (MENU + EXPANDABLE CATEGORIES + CART)
  // ---------------------------------------------------------------------------

  Widget _buildMenuItemCard(MenuItem item) {
    final inCartQty = _cart.entries.where((entry) {
      final key = entry.key;
      return key == item.id ||
          key.startsWith('${item.id}_var_') ||
          key.startsWith('${item.id}_cat_') ||
          key.startsWith('${item.id}+');
    }).fold(0, (sum, entry) => sum + entry.value);
    final itemColor = item.colorHex != null
        ? Color(item.colorHex!)
        : _getCategoryColor(item.category);

    return InkWell(
      key: ValueKey(item.id),
      onTap: () => _handleMenuItemTap(item),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  if (item.effectiveIsAddon)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.amber.shade700,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '+ Add-on',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  Text(
                    item.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
          ),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildCategoryAccordionCard(String catName, List<MenuItem> items) {
    final catColor = _getCategoryColor(catName);
    final isExpanded = !_collapsedCategories.contains(catName);

    return Card(
      key: PageStorageKey('pos_category_$catName'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _collapsedCategories.add(catName);
                } else {
                  _collapsedCategories.remove(catName);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 24,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      catName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
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
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: isExpanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: catColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite &&
                          constraints.maxWidth > 0
                      ? constraints.maxWidth
                      : (MediaQuery.of(context).size.width - 24);
                  const double maxExtent = 165.0;
                  const double spacing = 12.0;
                  const double childAspectRatio = 0.98;
                  int crossAxisCount =
                      (availableWidth / (maxExtent + spacing)).ceil();
                  crossAxisCount = crossAxisCount < 1 ? 1 : crossAxisCount;
                  final double usableWidth = math.max(
                    0.0,
                    availableWidth - spacing * (crossAxisCount - 1),
                  );
                  final double childWidth = usableWidth / crossAxisCount;
                  final double childHeight = childWidth / childAspectRatio;

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
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
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

    final targetItems = isConfirmedPayment
        ? _controller.getConfirmedOrderItems(order)
        : _controller.getPendingOrderItems(order);
    final itemsWithCategory = _controller.getOrderItemsWithCategory(
      order,
      customItems: targetItems.isNotEmpty ? targetItems : null,
    );

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
                            order.hasPartialPayment
                                ? 'Paid ₹${order.paidAmount.toStringAsFixed(0)} • ${order.paymentMethod ?? 'UPI'}'
                                : 'Paid • ${order.paymentMethod ?? 'UPI'}',
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
                            order.hasPartialPayment
                                ? '₹${order.remainingDue.toStringAsFixed(0)} Due • Paid ₹${order.paidAmount.toStringAsFixed(0)}'
                                : 'Payment Pending',
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
                  isConfirmedPayment && order.hasPartialPayment
                      ? '₹${order.paidAmount.toStringAsFixed(0)}'
                      : !isConfirmedPayment && order.hasPartialPayment
                          ? '₹${order.remainingDue.toStringAsFixed(0)}'
                          : '₹${order.total.toStringAsFixed(0)}',
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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

                          // Item Name & Category in brackets
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (!isConfirmedPayment &&
                                    order.hasPartialPayment &&
                                    !item.isPaidItem) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Extra • Pending',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                                ],
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
                        label: Text(
                          order.hasPartialPayment
                              ? 'Confirm ₹${order.remainingDue.toStringAsFixed(0)}'
                              : 'Confirm Payment',
                          style: const TextStyle(
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
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
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

import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';
import '../../theme/category_colors.dart';

/// Modal dialog for adding or editing menu items.
class AddEditMenuItemDialog {
  AddEditMenuItemDialog._();

  static void show(
    BuildContext context, {
    MenuItem? existingItem,
    required OrderController controller,
    required List<String> categories,
    required Color Function(String category) getCategoryColor,
    required Map<String, int> resolvedCategoryColors,
  }) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '',
    );
    String selectedCat =
        existingItem?.category ??
        (controller.selectedCategory != 'All'
            ? controller.selectedCategory
            : 'General');
    final categoryCtrl = TextEditingController(text: selectedCat);
    final linkedCategoryCtrl = TextEditingController(
      text: existingItem?.linkedCategory ??
          (existingItem?.isAddon == true ? existingItem?.category ?? '' : ''),
    );
    int? selectedColorHex = existingItem?.colorHex;
    bool isAddon = existingItem?.isAddon ?? false;

    final existingCategories = categories.where((c) => c != 'All').toList();
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
              : getCategoryColor(effectiveCategory);

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
                        if (val && linkedCategoryCtrl.text.trim().isEmpty) {
                          linkedCategoryCtrl.text = effectiveCategory;
                        }
                      });
                    },
                  ),
                  if (isAddon) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Link to Item Category',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This add-on will only be available for items in this category.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...existingCategories.map((cat) {
                          final isCurrent = linkedCategoryCtrl.text.trim().toLowerCase() ==
                              cat.trim().toLowerCase();
                          final catColor = getCategoryColor(cat);
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
                              color: isCurrent ? catColor : Colors.grey.shade300,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                            onSelected: (selected) {
                              setDialogState(() {
                                linkedCategoryCtrl.text = selected ? cat : '';
                              });
                            },
                          );
                        }),
                        ChoiceChip(
                          avatar: const Icon(Icons.all_inclusive, size: 12),
                          label: const Text('All Categories', style: TextStyle(fontSize: 12)),
                          selected: linkedCategoryCtrl.text.trim().toLowerCase() == 'all',
                          onSelected: (selected) {
                            setDialogState(() {
                              linkedCategoryCtrl.text = selected ? 'All' : '';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: linkedCategoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Target Category / Categories',
                        hintText: 'e.g. Beverages or Fast Food / Snacks',
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
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
                      final catColor = getCategoryColor(cat);
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
                      resolvedCategoryColors[category] ??
                      CategoryColorHelper.getUniqueColor(
                        categoryName: category,
                        usedColors: resolvedCategoryColors.values.toSet(),
                      );

                  final effectiveLinkedCategory = isAddon
                      ? (linkedCategoryCtrl.text.trim().isNotEmpty
                          ? linkedCategoryCtrl.text.trim()
                          : category)
                      : null;

                  if (name.isNotEmpty && price > 0) {
                    if (isEditing) {
                      controller.updateMenuItem(
                        existingItem.copyWith(
                          name: name,
                          price: price,
                          category: category,
                          colorHex: resolvedColor,
                          isAddon: isAddon,
                          linkedCategory: effectiveLinkedCategory,
                          clearLinkedCategory: !isAddon,
                        ),
                      );
                    } else {
                      controller.addMenuItem(
                        MenuItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name,
                          price: price,
                          category: category,
                          colorHex: resolvedColor,
                          isAddon: isAddon,
                          linkedCategory: effectiveLinkedCategory,
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

  static void showOptionsBottomSheet(
    BuildContext context, {
    required MenuItem item,
    required OrderController controller,
    required List<String> categories,
    required Color Function(String category) getCategoryColor,
    required Map<String, int> resolvedCategoryColors,
  }) {
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
                          : getCategoryColor(item.category),
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
                show(
                  context,
                  existingItem: item,
                  controller: controller,
                  categories: categories,
                  getCategoryColor: getCategoryColor,
                  resolvedCategoryColors: resolvedCategoryColors,
                );
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
                _confirmDeleteItem(context, item, controller);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmDeleteItem(
    BuildContext context,
    MenuItem item,
    OrderController controller,
  ) {
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
              controller.deleteMenuItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

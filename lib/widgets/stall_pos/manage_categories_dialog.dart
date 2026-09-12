import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import 'category_config_dialog.dart';

/// Modal dialog providing a centralized view to inspect, search, and edit
/// all menu category display names and additional surcharges/packaging fees.
class ManageCategoriesDialog extends StatefulWidget {
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const ManageCategoriesDialog({
    super.key,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ManageCategoriesDialog(
        controller: controller,
        getCategoryColor: getCategoryColor,
      ),
    );
  }

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  String _searchFilter = '';

  List<String> _getAllCategories() {
    final set = <String>{};
    // Include all categories discovered from active menu
    for (final c in widget.controller.categories) {
      if (c != 'All') set.add(c);
    }
    // Include all saved category configs
    for (final c in widget.controller.categoryConfigs) {
      if (c.name.trim().isNotEmpty && c.name.trim().toLowerCase() != 'all') {
        set.add(c.name.trim());
      }
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (_searchFilter.trim().isEmpty) return list;
    final query = _searchFilter.trim().toLowerCase();
    return list.where((cat) => cat.toLowerCase().contains(query)).toList();
  }

  void _addNewCategory() async {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final createdName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g. Desserts, Fresh Juices',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a category name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogCtx, nameCtrl.text.trim());
              }
            },
            child: const Text('Next: Set Details'),
          ),
        ],
      ),
    );

    if (createdName != null && createdName.isNotEmpty && mounted) {
      await CategoryConfigDialog.show(
        context,
        categoryName: createdName,
        controller: widget.controller,
        getCategoryColor: widget.getCategoryColor,
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final categories = _getAllCategories();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category Surcharges & Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Manage extra packaging fees and preparation option charges',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // Search + Add row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: 'Filter categories...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) => setState(() => _searchFilter = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _addNewCategory,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Category'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Category List
                Flexible(
                  child: categories.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: Text(
                            _searchFilter.isNotEmpty
                                ? 'No categories matching "$_searchFilter"'
                                : 'No categories found. Click "+ Add Category" to create one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 380),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: categories.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              final config = widget.controller.getCategoryConfig(cat);
                              final catColor = widget.getCategoryColor(cat);
                              final hasCost = config != null && config.hasAdditionalCost;
                              final isCostActive = hasCost && config.isEnabled;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                leading: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                                title: Text(
                                  cat,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isCostActive)
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepOrange.withAlpha(30),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.deepOrange.withAlpha(120),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  config.costDescription,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.deepOrange.shade800,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                          else if (hasCost && !config.isEnabled)
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withAlpha(40),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey.withAlpha(90), width: 0.8),
                                                ),
                                                child: Text(
                                                  '${config.costDescription} (Disabled)',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              'No extra surcharge',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasCost)
                                      Switch(
                                        value: config.isEnabled,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) async {
                                          await widget.controller.saveCategoryConfig(
                                            config.copyWith(isEnabled: val),
                                          );
                                        },
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      tooltip: 'Edit Surcharge & Display Name',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        await CategoryConfigDialog.show(
                                          context,
                                          categoryName: cat,
                                          controller: widget.controller,
                                          getCategoryColor: widget.getCategoryColor,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

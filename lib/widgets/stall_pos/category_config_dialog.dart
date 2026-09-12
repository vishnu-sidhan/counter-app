import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/item_category.dart';
import '../../theme/category_colors.dart';

class _OptionEntry {
  final String id;
  String name;
  final TextEditingController costCtrl;
  bool isEnabled;

  _OptionEntry({
    required this.id,
    required this.name,
    required this.costCtrl,
    this.isEnabled = true,
  });

  void dispose() {
    costCtrl.dispose();
  }
}

/// Modal dialog for configuring category settings such as display names,
/// multi-category variant charges (e.g. Steam/Fried/Pan Fried for Momos),
/// packaging fees, and category accent colors.
class CategoryConfigDialog extends StatefulWidget {
  final String categoryName;
  final OrderController controller;
  final Color Function(String category) getCategoryColor;

  const CategoryConfigDialog({
    super.key,
    required this.categoryName,
    required this.controller,
    required this.getCategoryColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String categoryName,
    required OrderController controller,
    required Color Function(String category) getCategoryColor,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => CategoryConfigDialog(
        categoryName: categoryName,
        controller: controller,
        getCategoryColor: getCategoryColor,
      ),
    );
  }

  @override
  State<CategoryConfigDialog> createState() => _CategoryConfigDialogState();
}

class _CategoryConfigDialogState extends State<CategoryConfigDialog> {
  late final ItemCategory _existingConfig;
  late final TextEditingController _costCtrl;
  late final TextEditingController _reasonCtrl;
  late final List<_OptionEntry> _optionEntries;

  late bool _isEnabled;
  late int? _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _existingConfig = widget.controller.getCategoryConfig(widget.categoryName) ??
        ItemCategory(
          id: 'cat_${widget.categoryName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          name: widget.categoryName.trim(),
          additionalCost: 0.0,
        );

    _costCtrl = TextEditingController(
      text: _existingConfig.additionalCost > 0
          ? (_existingConfig.additionalCost.truncateToDouble() == _existingConfig.additionalCost
              ? _existingConfig.additionalCost.toStringAsFixed(0)
              : _existingConfig.additionalCost.toStringAsFixed(2))
          : '',
    );
    _reasonCtrl = TextEditingController(
      text: _existingConfig.costReason ?? '',
    );

    _optionEntries = _existingConfig.effectiveOptions.map((opt) {
      return _OptionEntry(
        id: opt.id,
        name: opt.name,
        costCtrl: TextEditingController(
          text: opt.additionalCost > 0
              ? (opt.additionalCost.truncateToDouble() == opt.additionalCost
                  ? opt.additionalCost.toStringAsFixed(0)
                  : opt.additionalCost.toStringAsFixed(2))
              : '',
        ),
        isEnabled: opt.isEnabled,
      );
    }).toList();

    _isEnabled = _existingConfig.isEnabled;
    _selectedColorHex = _existingConfig.colorHex;
  }

  @override
  void dispose() {
    for (final opt in _optionEntries) {
      opt.dispose();
    }
    _costCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _addOptionPrompt() async {
    final newOptCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final addedName = await showDialog<String>(
      context: context,
      builder: (promptCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Category Option / Variant',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: newOptCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Option Name',
              hintText: 'e.g. Steam, Fried, Tandoori',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter option name';
              }
              if (_optionEntries.any(
                  (e) => e.name.trim().toLowerCase() == val.trim().toLowerCase())) {
                return 'Option already exists';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(promptCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(promptCtx, newOptCtrl.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (addedName != null && addedName.isNotEmpty && mounted) {
      setState(() {
        _optionEntries.add(
          _OptionEntry(
            id: 'opt_${addedName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
            name: addedName,
            costCtrl: TextEditingController(text: ''),
            isEnabled: true,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.getCategoryColor(widget.categoryName);
    final currentColor =
        _selectedColorHex != null ? Color(_selectedColorHex!) : baseColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            width: 10,
            height: 24,
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Category: ${widget.categoryName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure category option / variant charges (e.g. Steam / Fried / Pan Fried for Momos), packaging fees, and accent colors.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),

              // Category Options Section (for multi-categories like Steam / Fried / Pan Fried)
              if (_optionEntries.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 16, color: currentColor),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Option / Variant Charges',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addOptionPrompt,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set individual additional cost for each category option (e.g. Steam: ₹0, Fried: ₹10, Pan Fried: ₹20).',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._optionEntries.asMap().entries.map((item) {
                        final index = item.key;
                        final entry = item.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: currentColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: currentColor.withAlpha(70)),
                                  ),
                                  child: Text(
                                    entry.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: entry.costCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    hintText: '0',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Checkbox(
                                value: entry.isEnabled,
                                onChanged: (val) {
                                  setState(() {
                                    entry.isEnabled = val ?? true;
                                  });
                                },
                              ),
                              if (_optionEntries.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Remove option',
                                  onPressed: () {
                                    setState(() {
                                      _optionEntries.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                // Single-cost category inputs
                TextField(
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Additional Cost (₹)',
                    hintText: 'e.g. 5, 10',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    helperText: 'Applied to items in this category',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Reason / Label (Optional)',
                    hintText: 'e.g. Packaging Fee, Container Charge',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    'Packaging Fee',
                    'Container Charge',
                    'Takeaway Surcharge',
                    'Eco Box',
                  ].map((reason) {
                    return ActionChip(
                      label: Text(reason, style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _reasonCtrl.text = reason;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _addOptionPrompt,
                  icon: const Icon(Icons.alt_route_rounded, size: 16),
                  label: const Text(
                    'Add Sub-Category Options / Variants',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Enable/Disable switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Additional Cost',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Toggle off to temporarily disable charges without deleting them',
                  style: TextStyle(fontSize: 11),
                ),
                value: _isEnabled,
                onChanged: (val) {
                  setState(() {
                    _isEnabled = val;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Color selection row
              Row(
                children: [
                  const Text(
                    'Category Color Accent',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: CategoryColorHelper.palette.take(8).map((colorInt) {
                  final c = Color(colorInt);
                  final isSelected = _selectedColorHex == colorInt;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColorHex = colorInt;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.withAlpha(150),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final parsedCost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
            final cleanReason = _reasonCtrl.text.trim().isNotEmpty
                ? _reasonCtrl.text.trim()
                : null;

            final updatedOptions = _optionEntries.map((e) {
              final parsedOptCost =
                  double.tryParse(e.costCtrl.text.trim()) ?? 0.0;
              return CategoryOption(
                id: e.id,
                name: e.name,
                additionalCost: parsedOptCost >= 0 ? parsedOptCost : 0.0,
                isEnabled: e.isEnabled,
              );
            }).toList();

            final updated = _existingConfig.copyWith(
              name: widget.categoryName.trim(),
              additionalCost: parsedCost >= 0 ? parsedCost : 0.0,
              costReason: cleanReason,
              clearCostReason: cleanReason == null,
              isEnabled: _isEnabled,
              colorHex: _selectedColorHex,
              options: updatedOptions,
            );

            await widget.controller.saveCategoryConfig(updated);

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}

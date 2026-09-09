import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/counter_model.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet for creating a new counter or updating an existing counter.
class AddEditCounterSheet extends StatefulWidget {
  final CounterModel? counterToEdit;
  final void Function({
    required String title,
    required int initialCount,
    required int step,
    required int colorHex,
    int? target,
    required bool allowNegative,
    String? tag,
  }) onSave;

  const AddEditCounterSheet({
    super.key,
    this.counterToEdit,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    CounterModel? counterToEdit,
    required void Function({
      required String title,
      required int initialCount,
      required int step,
      required int colorHex,
      int? target,
      required bool allowNegative,
      String? tag,
    }) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditCounterSheet(
        counterToEdit: counterToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditCounterSheet> createState() => _AddEditCounterSheetState();
}

class _AddEditCounterSheetState extends State<AddEditCounterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _tagController;
  late final TextEditingController _countController;
  late final TextEditingController _stepController;
  late final TextEditingController _targetController;

  late int _selectedColorHex;
  late bool _allowNegative;
  late int _stepValue;

  final List<int> _presetSteps = [1, 2, 5, 10, 25];

  @override
  void initState() {
    super.initState();
    final edit = widget.counterToEdit;
    _titleController = TextEditingController(text: edit?.title ?? '');
    _tagController = TextEditingController(text: edit?.tag ?? '');
    _countController = TextEditingController(text: (edit?.count ?? 0).toString());
    _stepValue = edit?.step ?? 1;
    _stepController = TextEditingController(text: _stepValue.toString());
    _targetController = TextEditingController(
      text: edit?.target != null ? edit!.target.toString() : '',
    );
    _selectedColorHex = edit?.colorHex ?? AppTheme.presets.first.hex;
    _allowNegative = edit?.allowNegative ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    _countController.dispose();
    _stepController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _onStepPresetSelected(int step) {
    setState(() {
      _stepValue = step;
      _stepController.text = step.toString();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final tagText = _tagController.text.trim();
    final count = int.tryParse(_countController.text.trim()) ?? 0;
    final step = int.tryParse(_stepController.text.trim()) ?? 1;
    final targetText = _targetController.text.trim();
    final target = targetText.isNotEmpty ? int.tryParse(targetText) : null;

    widget.onSave(
      title: title,
      initialCount: count,
      step: step <= 0 ? 1 : step,
      colorHex: _selectedColorHex,
      target: (target != null && target > 0) ? target : null,
      allowNegative: _allowNegative,
      tag: tagText.isNotEmpty ? tagText : null,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.counterToEdit != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Counter' : 'Create New Counter',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Counter Title Field
              TextFormField(
                controller: _titleController,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Counter Name *',
                  hintText: 'e.g. Glasses of Water, Pushups, Daily Pages',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name for this counter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category / Tag Field
              TextFormField(
                controller: _tagController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category / Tag (Optional)',
                  hintText: 'e.g. Fitness, Work, Habits, Daily',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Starting / Current Count & Step row
              Row(
                children: [
                  // Count
                  Expanded(
                    child: TextFormField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Current Count' : 'Starting Count',
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Step size
                  Expanded(
                    child: TextFormField(
                      controller: _stepController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Step Value',
                        prefixIcon: Icon(Icons.exposure_plus_1_outlined),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          setState(() => _stepValue = parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Step Presets Chips
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Presets:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  ..._presetSteps.map((step) {
                    final isSelected = _stepValue == step;
                    return ChoiceChip(
                      label: Text('±$step'),
                      selected: isSelected,
                      onSelected: (_) => _onStepPresetSelected(step),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Target Goal Field
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Target Goal (Optional)',
                  hintText: 'e.g. 10 glasses, 100 reps',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Color Palette Selector
              Text(
                'Color Theme',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppTheme.presets.map((preset) {
                  final isSelected = _selectedColorHex == preset.hex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedColorHex = preset.hex);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: preset.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: preset.color.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 22,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Allow Negative Count Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow Negative Numbers'),
                subtitle: const Text('Allow decrementing below 0'),
                value: _allowNegative,
                onChanged: (val) => setState(() => _allowNegative = val),
              ),
              const SizedBox(height: 24),

              // Submit Button
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  isEditing ? 'Save Changes' : 'Create Counter',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

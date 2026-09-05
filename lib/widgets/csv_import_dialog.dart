import 'package:flutter/material.dart';
import '../data/models/counter_model.dart';
import '../data/models/stall_models.dart';
import '../services/csv_import_service.dart';

enum CsvImportType { menuItem, counter }

/// Universal dialog for importing POS Menu Items or Counters from CSV file or raw text.
class CsvImportDialog<T> extends StatefulWidget {
  final CsvImportType importType;
  final int existingItemsCount;
  final void Function(List<T> items, bool replaceExisting) onImport;

  const CsvImportDialog({
    super.key,
    required this.importType,
    required this.existingItemsCount,
    required this.onImport,
  });

  /// Helper to show the dialog for POS Menu Items.
  static Future<void> showMenuItemsDialog(
    BuildContext context, {
    required int existingCount,
    required void Function(List<MenuItem> items, bool replaceExisting) onImport,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CsvImportDialog<MenuItem>(
        importType: CsvImportType.menuItem,
        existingItemsCount: existingCount,
        onImport: onImport,
      ),
    );
  }

  /// Helper to show the dialog for Counters.
  static Future<void> showCountersDialog(
    BuildContext context, {
    required int existingCount,
    required void Function(List<CounterModel> items, bool replaceExisting) onImport,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CsvImportDialog<CounterModel>(
        importType: CsvImportType.counter,
        existingItemsCount: existingCount,
        onImport: onImport,
      ),
    );
  }

  @override
  State<CsvImportDialog<T>> createState() => _CsvImportDialogState<T>();
}

class _CsvImportDialogState<T> extends State<CsvImportDialog<T>>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();

  String? _selectedFileName;
  bool _replaceExisting = false;
  bool _isLoadingFile = false;
  String? _errorMessage;

  List<T> _parsedItems = [];
  int _skippedRows = 0;
  List<String> _warnings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _parseCsvContent(_textController.text);
  }

  void _parseCsvContent(String rawText) {
    if (rawText.trim().isEmpty) {
      setState(() {
        _parsedItems = [];
        _skippedRows = 0;
        _warnings = [];
        _errorMessage = null;
      });
      return;
    }

    if (widget.importType == CsvImportType.menuItem) {
      final res = CsvImportService.parseMenuItemsFromCsv(rawText);
      setState(() {
        _parsedItems = res.items as List<T>;
        _skippedRows = res.skippedRowsCount;
        _warnings = res.warnings;
        _errorMessage = res.items.isEmpty && res.warnings.isNotEmpty
            ? res.warnings.first
            : null;
      });
    } else {
      final res = CsvImportService.parseCountersFromCsv(rawText);
      setState(() {
        _parsedItems = res.items as List<T>;
        _skippedRows = res.skippedRowsCount;
        _warnings = res.warnings;
        _errorMessage = res.items.isEmpty && res.warnings.isNotEmpty
            ? res.warnings.first
            : null;
      });
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoadingFile = true;
      _errorMessage = null;
    });

    try {
      final selection = await CsvImportService.pickCsvFile();
      if (selection != null) {
        setState(() {
          _selectedFileName = selection.fileName;
          _textController.text = selection.content;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not read file: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFile = false;
        });
      }
    }
  }

  void _loadSampleTemplate() {
    final sample = widget.importType == CsvImportType.menuItem
        ? CsvImportService.sampleMenuCsv
        : CsvImportService.sampleCountersCsv;
    _textController.text = sample;
    _selectedFileName = null;
  }

  void _confirmImport() {
    if (_parsedItems.isEmpty) return;
    widget.onImport(_parsedItems, _replaceExisting);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMenu = widget.importType == CsvImportType.menuItem;
    final title = isMenu ? 'Import POS Menu Items' : 'Import Counters from CSV';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.file_upload_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isMenu
                              ? 'CSV headers: name, price, category'
                              : 'CSV headers: title, count, step, target, allowNegative',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.upload_file, size: 18), text: 'Upload File'),
                  Tab(icon: Icon(Icons.edit_note, size: 18), text: 'Paste Text'),
                ],
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUploadFileTab(theme),
                    _buildPasteTextTab(theme),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Live Preview & Status
              if (_parsedItems.isNotEmpty || _skippedRows > 0 || _errorMessage != null)
                _buildPreviewSection(theme),

              const SizedBox(height: 10),

              // Import Mode Options (Append vs Replace)
              _buildImportModeSelector(theme),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _parsedItems.isEmpty ? null : _confirmImport,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      _parsedItems.isEmpty
                          ? 'Import'
                          : 'Import ${_parsedItems.length} Item${_parsedItems.length == 1 ? '' : 's'}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadFileTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          InkWell(
            onTap: _isLoadingFile ? null : _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? 'Tap to browse and select a .csv file',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: _selectedFileName != null
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: _selectedFileName != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supports UTF-8 encoded comma-separated files',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isLoadingFile)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: Text(_selectedFileName == null ? 'Browse CSV' : 'Change File'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              _loadSampleTemplate();
              _tabController.animateTo(1);
            },
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: const Text('Try with sample data in Paste Tab'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteTextTab(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Paste CSV:',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _loadSampleTemplate,
              icon: const Icon(Icons.content_paste_go, size: 14),
              label: const Text('Load Sample', style: TextStyle(fontSize: 12)),
            ),
            if (_textController.text.isNotEmpty)
              IconButton(
                onPressed: () => _textController.clear(),
                icon: const Icon(Icons.clear, size: 16),
                tooltip: 'Clear',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            decoration: InputDecoration(
              hintText: widget.importType == CsvImportType.menuItem
                  ? 'name,price,category\nMasala Chai,20,Beverages\nVeg Samosa,25,Snacks'
                  : 'title,count,step,target,allowNegative\nWater,0,1,8,false',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges
          Row(
            children: [
              if (_parsedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✓ ${_parsedItems.length} items parsed',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_skippedRows > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠ $_skippedRows skipped',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _warnings.first,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.error,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: _parsedItems.length,
              itemBuilder: (context, index) {
                final item = _parsedItems[index];
                if (item is MenuItem) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${item.name} (${item.category})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (item is CounterModel) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${item.title} (Step: ${item.step})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          item.target != null ? 'Target: ${item.target}' : 'No target',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportModeSelector(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment<bool>(
            value: false,
            label: Text(
              'Append (${widget.existingItemsCount} current)',
              style: const TextStyle(fontSize: 12),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16),
          ),
          const ButtonSegment<bool>(
            value: true,
            label: Text('Replace All', style: TextStyle(fontSize: 12)),
            icon: Icon(Icons.refresh_rounded, size: 16),
          ),
        ],
        selected: {_replaceExisting},
        onSelectionChanged: (newSelection) {
          setState(() => _replaceExisting = newSelection.first);
        },
      ),
    );
  }
}

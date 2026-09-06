import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/stall_models.dart';
import '../data/services/stall_storage_service.dart';
import '../services/csv_export_service.dart';

enum OrderHistoryFilter { all, completed, pending }

class OrderHistoryScreen extends StatefulWidget {
  final StallStorageService storageService;
  final VoidCallback? onOrdersChanged;

  const OrderHistoryScreen({
    super.key,
    required this.storageService,
    this.onOrdersChanged,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<StallOrder> _orders = [];
  bool _isLoading = true;
  OrderHistoryFilter _filter = OrderHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final loaded = await widget.storageService.loadOrders();
    // Sort descending by token / timestamp (most recent first)
    loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _orders = loaded;
        _isLoading = false;
      });
    }
  }

  List<StallOrder> get _filteredOrders {
    switch (_filter) {
      case OrderHistoryFilter.completed:
        return _orders.where((o) => o.isCompleted).toList();
      case OrderHistoryFilter.pending:
        return _orders.where((o) => !o.isCompleted).toList();
      case OrderHistoryFilter.all:
        return _orders;
    }
  }

  double get _totalRevenue =>
      _orders.fold(0.0, (sum, o) => sum + o.total);

  int get _completedCount =>
      _orders.where((o) => o.isCompleted).length;

  int get _pendingCount =>
      _orders.where((o) => !o.isCompleted).length;

  double get _avgOrderValue =>
      _orders.isEmpty ? 0.0 : _totalRevenue / _orders.length;

  Future<void> _exportCsv() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No orders to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await CsvExportService.exportOrdersCsv(orders: _filteredOrders);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order history CSV exported successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmClearCompleted() {
    if (_completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed orders to clear.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Completed Orders?'),
        content: Text(
          'This will permanently remove $_completedCount completed orders from history. Active/pending orders will be kept.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              final remaining = await widget.storageService.clearCompletedOrders();
              remaining.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              if (mounted) {
                setState(() => _orders = remaining);
                widget.onOrdersChanged?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completed orders cleared.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear Completed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download CSV',
            onPressed: _orders.isEmpty ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Completed',
            onPressed: _completedCount == 0 ? null : _confirmClearCompleted,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Metrics Banner
                _buildSummaryBanner(theme),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All (${_orders.length})',
                        filter: OrderHistoryFilter.all,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Completed ($_completedCount)',
                        filter: OrderHistoryFilter.completed,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Pending ($_pendingCount)',
                        filter: OrderHistoryFilter.pending,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Orders List
                Expanded(
                  child: _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order, theme);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', theme.colorScheme.primary),
          _buildDivider(),
          _buildStatItem('Orders', '${_orders.length}', theme.colorScheme.onSurface),
          _buildDivider(),
          _buildStatItem('Avg Value', '₹${_avgOrderValue.toStringAsFixed(0)}', theme.colorScheme.secondary),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.withAlpha(60),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required OrderHistoryFilter filter,
  }) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'No orders found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Orders punched from Stall POS will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
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
              final allOrders = await widget.storageService.loadOrders();
              allOrders.removeWhere((o) => o.token == token);
              await widget.storageService.saveOrders(allOrders);
              await _loadOrders();
              widget.onOrdersChanged?.call();
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

  Widget _buildOrderCard(StallOrder order, ThemeData theme) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final timeStr = dateFormat.format(order.timestamp);

    String durationStr = '';
    if (order.isCompleted && order.completedAt != null) {
      final diff = order.completedAt!.difference(order.timestamp).inMinutes;
      durationStr = diff == 0 ? 'Took <1 min' : 'Took $diff mins';
    }

    final cardBorderColor = order.isCompleted
        ? Colors.green.shade600
        : Colors.orange.shade700;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cardBorderColor.withAlpha(120), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Token pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.isCompleted ? Colors.green.shade700 : Colors.orange.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${order.token}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.isCompleted
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: order.isCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    order.isCompleted ? 'Completed' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: order.isCompleted
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
                if (durationStr.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    durationStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const Spacer(),

                // Total price
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Name & Payment badge
            Row(
              children: [
                Icon(
                  order.customerName != null && order.customerName!.trim().isNotEmpty
                      ? Icons.person
                      : Icons.person_outline,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  order.displayCustomerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (order.paymentMethod != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.paymentMethod!,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Items breakdown
            Text(
              order.itemsSummary,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),

            // Timestamp & Delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'Delete Order',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDeleteOrder(order.token),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

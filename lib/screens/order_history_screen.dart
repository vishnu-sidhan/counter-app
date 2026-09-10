import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/order_controller.dart';
import '../data/models/stall_models.dart';
import '../data/storage/stall_storage.dart';
import '../data/storage/app_storage.dart';
import '../services/csv_export_service.dart';

enum OrderHistoryFilter { all, completed, pending, fullyPaid, partial, unpaid }
enum OrderDateRangeFilter { allTime, today, yesterday, last7Days }

class OrderHistoryScreen extends StatefulWidget {
  final StallStorage? storageService;
  final OrderController? controller;
  final VoidCallback? onOrdersChanged;

  const OrderHistoryScreen({
    super.key,
    this.storageService,
    this.controller,
    this.onOrdersChanged,
  }) : assert(storageService != null || controller != null);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<StallOrder> _orders = [];
  bool _isLoading = true;
  OrderHistoryFilter _filter = OrderHistoryFilter.all;
  OrderDateRangeFilter _dateFilter = OrderDateRangeFilter.allTime;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  StallStorage get _effectiveStorageService =>
      widget.controller?.storageService ?? widget.storageService ?? AppStorage.instance.stallStorage;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      widget.controller!.addListener(_onControllerChanged);
    }
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() => _searchQuery = q);
      }
    });
    _loadOrders();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted && widget.controller != null) {
      final list = List<StallOrder>.from(widget.controller!.orders);
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _orders = list;
      });
    }
  }

  Future<void> _loadOrders() async {
    if (widget.controller != null) {
      final list = List<StallOrder>.from(widget.controller!.orders);
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } else {
      final loaded = await _effectiveStorageService.loadOrders();
      // Sort descending by token / timestamp (most recent first)
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _orders = loaded;
          _isLoading = false;
        });
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<StallOrder> get _filteredOrders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    return _orders.where((o) {
      // 1. Status Filter
      if (_filter == OrderHistoryFilter.completed && !o.isCompleted) return false;
      if (_filter == OrderHistoryFilter.pending && o.isCompleted) return false;

      // 2. Date Range Filter
      switch (_dateFilter) {
        case OrderDateRangeFilter.allTime:
          break;
        case OrderDateRangeFilter.today:
          if (!_isSameDay(o.timestamp, now)) return false;
          break;
        case OrderDateRangeFilter.yesterday:
          if (!_isSameDay(o.timestamp, yesterday)) return false;
          break;
        case OrderDateRangeFilter.last7Days:
          if (o.timestamp.isBefore(sevenDaysAgo)) return false;
          break;
      }

      // 3. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final tokenStr = '#${o.token}';
        final tokenRaw = o.token.toString();
        final custName = o.displayCustomerName.toLowerCase();
        final summary = o.itemsSummary.toLowerCase();
        final match = tokenStr.contains(_searchQuery) ||
            tokenRaw.contains(_searchQuery) ||
            custName.contains(_searchQuery) ||
            summary.contains(_searchQuery);
        if (!match) return false;
      }

      return true;
    }).toList();
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

  void _confirmArchiveCompleted() {
    if (_completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed orders to archive.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Completed Orders?'),
        content: Text(
          'This will move $_completedCount completed orders into long-term archive storage to keep active history fast. You can still export archived orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.controller != null) {
                await widget.controller!.archiveCompletedOrders();
              } else {
                final completed = _orders.where((o) => o.isCompleted).toList();
                await _effectiveStorageService.archiveCompletedOrders(explicitOrders: completed);
                await _effectiveStorageService.clearCompletedOrders();
                await _loadOrders();
              }
              widget.onOrdersChanged?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Completed orders archived successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
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
              if (widget.controller != null) {
                await widget.controller!.clearCompletedOrders();
              } else {
                final remaining = await _effectiveStorageService.clearCompletedOrders();
                remaining.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                if (mounted) {
                  setState(() => _orders = remaining);
                }
              }
              widget.onOrdersChanged?.call();
              if (mounted) {
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
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive Completed',
            onPressed: _completedCount == 0 ? null : _confirmArchiveCompleted,
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

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by #Token, Customer, or Items...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
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

                // Filter Chips (Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: Colors.grey.withAlpha(80)),
                      const SizedBox(width: 12),
                      // Date Range Chips
                      _buildDateFilterChip('All Time', OrderDateRangeFilter.allTime),
                      const SizedBox(width: 6),
                      _buildDateFilterChip('Today', OrderDateRangeFilter.today),
                      const SizedBox(width: 6),
                      _buildDateFilterChip('Yesterday', OrderDateRangeFilter.yesterday),
                      const SizedBox(width: 6),
                      _buildDateFilterChip('Last 7 Days', OrderDateRangeFilter.last7Days),
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

  Widget _buildDateFilterChip(String label, OrderDateRangeFilter dateFilter) {
    final isSelected = _dateFilter == dateFilter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _dateFilter = dateFilter),
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
          Text(
            _searchQuery.isNotEmpty ? 'No matching orders found' : 'No orders found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term or clear filters'
                : 'Orders punched from Stall POS will appear here',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
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
              if (widget.controller != null) {
                await widget.controller!.deleteOrder(token);
              } else {
                final allOrders = await _effectiveStorageService.loadOrders();
                allOrders.removeWhere((o) => o.token == token);
                await _effectiveStorageService.saveOrders(allOrders);
                await _loadOrders();
              }
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

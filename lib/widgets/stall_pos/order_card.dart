import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';

/// Card displaying an active order ticket with elapsed time, payment status,
/// item breakdowns, and quick action buttons (confirm payment, edit, delete, done).
class OrderCard extends StatefulWidget {
  final StallOrder order;
  final bool isConfirmedPayment;
  final OrderController controller;
  final ValueChanged<StallOrder>? onConfirmPayment;
  final ValueChanged<StallOrder>? onEditOrder;
  final ValueChanged<int>? onDeleteOrder;
  final ValueChanged<int>? onCompleteOrder;

  const OrderCard({
    super.key,
    required this.order,
    required this.isConfirmedPayment,
    required this.controller,
    this.onConfirmPayment,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onCompleteOrder,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    // Refresh elapsed time every 15 seconds locally without rebuilding parent tree
    _elapsedTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isConfirmedPayment = widget.isConfirmedPayment;
    final controller = widget.controller;

    final now = DateTime.now();
    final diffMinutes = now.difference(order.timestamp).inMinutes;

    Color cardBorderColor = Colors.blue.shade700;
    if (diffMinutes >= 7) {
      cardBorderColor = Colors.red.shade700;
    } else if (diffMinutes >= 3) {
      cardBorderColor = Colors.orange.shade800;
    }

    final targetItems = isConfirmedPayment
        ? controller.getConfirmedOrderItems(order)
        : controller.getPendingOrderItems(order);
    final itemsWithCategory = controller.getOrderItemsWithCategory(
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

            // Vertical list of items with categories
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
                    if (!isConfirmedPayment) ...[
                      FilledButton.icon(
                        key: ValueKey('confirm_payment_btn_${order.token}'),
                        onPressed: () => widget.onConfirmPayment?.call(order),
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

                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Order',
                      onPressed: () => widget.onEditOrder?.call(order),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),

                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: 'Delete Order',
                      onPressed: () => widget.onDeleteOrder?.call(order.token),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),

                    if (isConfirmedPayment) ...[
                      const SizedBox(width: 6),
                      FilledButton.tonal(
                        onPressed: () => widget.onCompleteOrder?.call(order.token),
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
}

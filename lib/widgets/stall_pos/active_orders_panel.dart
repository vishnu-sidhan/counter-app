import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../data/models/stall_models.dart';
import 'order_card.dart';

/// Panel displaying active orders split into two sections:
/// 1. Confirmed Payment Orders (ready for preparation)
/// 2. To Confirm Payment Orders (pending cashier payment confirmation)
class ActiveOrdersPanel extends StatelessWidget {
  final OrderController controller;
  final ValueChanged<StallOrder>? onConfirmPayment;
  final ValueChanged<StallOrder>? onEditOrder;
  final ValueChanged<int>? onDeleteOrder;
  final ValueChanged<int>? onCompleteOrder;

  const ActiveOrdersPanel({
    super.key,
    required this.controller,
    this.onConfirmPayment,
    this.onEditOrder,
    this.onDeleteOrder,
    this.onCompleteOrder,
  });

  @override
  Widget build(BuildContext context) {
    final confirmed = controller.confirmedActiveOrders;
    final toConfirm = controller.toConfirmPaymentOrders;

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
            (order) => OrderCard(
              order: order,
              isConfirmedPayment: true,
              controller: controller,
              onConfirmPayment: onConfirmPayment,
              onEditOrder: onEditOrder,
              onDeleteOrder: onDeleteOrder,
              onCompleteOrder: onCompleteOrder,
            ),
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
            (order) => OrderCard(
              order: order,
              isConfirmedPayment: false,
              controller: controller,
              onConfirmPayment: onConfirmPayment,
              onEditOrder: onEditOrder,
              onDeleteOrder: onDeleteOrder,
              onCompleteOrder: onCompleteOrder,
            ),
          ),
      ],
    );
  }
}

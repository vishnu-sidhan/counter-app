import 'package:flutter/material.dart';
import '../../controllers/order_controller.dart';
import '../../theme/category_colors.dart';

/// Panel displaying consolidated item preparation queue across all active tickets,
/// with interactive completion per ticket or by batch.
class ItemSummaryPanel extends StatelessWidget {
  final OrderController controller;
  final Color Function(String category)? getCategoryColor;
  final void Function(int token, String itemId, String itemName, int quantity)? onCompleteTicketItem;
  final void Function(String itemId, String itemName)? onCompleteAllItem;

  const ItemSummaryPanel({
    super.key,
    required this.controller,
    this.getCategoryColor,
    this.onCompleteTicketItem,
    this.onCompleteAllItem,
  });

  Color _resolveCategoryColor(String category, int? itemColorHex) {
    if (itemColorHex != null) {
      return Color(itemColorHex);
    }
    if (getCategoryColor != null) {
      return getCategoryColor!(category);
    }
    return Color(CategoryColorHelper.getColorForCategory(category));
  }

  @override
  Widget build(BuildContext context) {
    final combined = controller.combinedActiveOrders;

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
        final color = _resolveCategoryColor(item.category, item.colorHex);

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
                  height: 52,
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
                            return Tooltip(
                              message: 'Tap to mark done for Order #${t.token}',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('ticket_chip_${item.itemId}_${t.token}'),
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    if (onCompleteTicketItem != null) {
                                      onCompleteTicketItem!(
                                        t.token,
                                        item.itemId,
                                        item.itemName,
                                        t.quantity,
                                      );
                                    } else {
                                      controller.completeOrderItem(
                                        token: t.token,
                                        itemId: item.itemId,
                                        quantity: t.quantity,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant.withAlpha(100),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          size: 13,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '#${t.token} (${t.quantity})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

                // Right action area: Large Badge with Total Quantity + Quick Complete Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: CategoryColorHelper.getContrastingTextColor(color),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.tonalIcon(
                      key: ValueKey('complete_btn_${item.itemId}'),
                      onPressed: () {
                        if (item.tickets.length == 1) {
                          final t = item.tickets.first;
                          if (onCompleteTicketItem != null) {
                            onCompleteTicketItem!(
                              t.token,
                              item.itemId,
                              item.itemName,
                              t.quantity,
                            );
                          } else {
                            controller.completeOrderItem(
                              token: t.token,
                              itemId: item.itemId,
                              quantity: t.quantity,
                            );
                          }
                        } else {
                          if (onCompleteAllItem != null) {
                            onCompleteAllItem!(item.itemId, item.itemName);
                          } else {
                            controller.completeAggregatedItem(item.itemId);
                          }
                        }
                      },
                      icon: Icon(
                        item.tickets.length == 1 ? Icons.check : Icons.done_all,
                        size: 13,
                      ),
                      label: Text(
                        item.tickets.length == 1 ? 'Done' : 'All Done',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        foregroundColor: Colors.green.shade900,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

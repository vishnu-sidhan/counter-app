import 'package:flutter/material.dart';

/// Result returned from PaymentConfirmationDialog upon confirmation.
class PaymentResult {
  final String paymentMethod;
  final double? amountReceived;
  final double? changeToReturn;

  const PaymentResult({
    required this.paymentMethod,
    this.amountReceived,
    this.changeToReturn,
  });
}

/// Modal dialog for confirming payment before completing or updating an order.
class PaymentConfirmationDialog extends StatefulWidget {
  final int orderNumber;
  final bool isEditing;
  final double totalDue;
  final String customerName;

  const PaymentConfirmationDialog({
    super.key,
    required this.orderNumber,
    this.isEditing = false,
    required this.totalDue,
    required this.customerName,
  });

  /// Static helper to display the dialog
  static Future<PaymentResult?> show(
    BuildContext context, {
    required int orderNumber,
    bool isEditing = false,
    required double totalDue,
    required String customerName,
  }) {
    return showDialog<PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentConfirmationDialog(
        orderNumber: orderNumber,
        isEditing: isEditing,
        totalDue: totalDue,
        customerName: customerName,
      ),
    );
  }

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  String _selectedMethod = 'Cash'; // Default
  final TextEditingController _receivedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default received amount to exact total due for convenient 1-tap checkout
    _receivedCtrl.text = widget.totalDue.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    super.dispose();
  }

  double get _amountReceived =>
      double.tryParse(_receivedCtrl.text.trim()) ?? 0.0;

  double get _changeToReturn => _amountReceived - widget.totalDue;

  void _onConfirm() {
    final method = _selectedMethod;
    final received = method == 'Cash' ? _amountReceived : null;
    final change = method == 'Cash' ? (_changeToReturn > 0 ? _changeToReturn : 0.0) : null;

    Navigator.of(context).pop(
      PaymentResult(
        paymentMethod: method,
        amountReceived: received,
        changeToReturn: change,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCash = _selectedMethod == 'Cash';
    final effectiveCustomerName = widget.customerName.trim().isNotEmpty
        ? widget.customerName.trim()
        : 'Walk-in Customer';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payments_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing
                      ? 'Update Order #${widget.orderNumber}'
                      : 'Order #${widget.orderNumber}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Payment Confirmation',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Due Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Due',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '₹${widget.totalDue.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Customer Name Badge
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text(
                  'Customer: ',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                Chip(
                  avatar: const Icon(Icons.person, size: 14),
                  label: Text(
                    effectiveCustomerName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment Method Selector
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.money_rounded, size: 18),
                    label: const Center(child: Text('Cash')),
                    selected: _selectedMethod == 'Cash',
                    selectedColor: theme.colorScheme.primaryContainer,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedMethod = 'Cash');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Center(child: Text('UPI / QR')),
                    selected: _selectedMethod == 'UPI',
                    selectedColor: theme.colorScheme.primaryContainer,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedMethod = 'UPI');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cash Received & Change Calculator
            if (isCash) ...[
              TextField(
                controller: _receivedCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹)',
                  prefixText: '₹ ',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // Quick tender increment chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      label: Text('Exact (₹${widget.totalDue.toStringAsFixed(0)})'),
                      onPressed: () {
                        setState(() {
                          _receivedCtrl.text =
                              widget.totalDue.toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('+₹50'),
                      onPressed: () {
                        setState(() {
                          final current = _amountReceived;
                          _receivedCtrl.text =
                              (current + 50).toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('+₹100'),
                      onPressed: () {
                        setState(() {
                          final current = _amountReceived;
                          _receivedCtrl.text =
                              (current + 100).toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      label: const Text('+₹500'),
                      onPressed: () {
                        setState(() {
                          final current = _amountReceived;
                          _receivedCtrl.text =
                              (current + 500).toStringAsFixed(0);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Change to return display
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _changeToReturn >= 0
                      ? Colors.green.withAlpha(25)
                      : Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _changeToReturn >= 0
                        ? Colors.green.withAlpha(80)
                        : Colors.orange.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _changeToReturn >= 0 ? 'Change to Return:' : 'Amount Short:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _changeToReturn >= 0
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      _changeToReturn >= 0
                          ? '₹${_changeToReturn.toStringAsFixed(0)}'
                          : '₹${(-_changeToReturn).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _changeToReturn >= 0
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // UPI Prompt
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scan UPI QR on stall terminal for ₹${widget.totalDue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Back to Cart'),
        ),
        FilledButton.icon(
          onPressed: _onConfirm,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            widget.isEditing
                ? 'Confirm & Update'
                : 'Confirm Payment & Complete',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

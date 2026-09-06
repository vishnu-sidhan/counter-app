import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/controllers/theme_controller.dart';
import 'package:counter_app/screens/stall_pos_screen.dart';
import 'package:counter_app/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {
          'id': 'item_1',
          'name': 'Masala Chai',
          'price': 20.0,
          'category': 'Beverages',
        },
        {
          'id': 'item_2',
          'name': 'Veg Samosa',
          'price': 25.0,
          'category': 'Snacks',
        },
      ]),
      'stall_orders': jsonEncode([
        {
          'token': 101,
          'itemsSummary': '2x Masala Chai',
          'total': 40.0,
          'timestamp': DateTime.now().toIso8601String(),
          'customerName': 'Vikram',
          'isPaid': true,
          'paymentMethod': 'Cash',
          'items': {'item_1': 2},
        },
        {
          'token': 102,
          'itemsSummary': '1x Masala Chai, 2x Veg Samosa',
          'total': 70.0,
          'timestamp': DateTime.now().toIso8601String(),
          'customerName': null,
          'isPaid': true,
          'paymentMethod': 'UPI',
          'items': {'item_1': 1, 'item_2': 2},
        },
      ]),
      'stall_next_token': 103,
    });
  });

  testWidgets(
    'StallPosScreen renders 3 tabs on mobile and shows badge counts',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Verify 3 tabs present
      expect(find.text('POS / Register'), findsOneWidget);
      expect(find.text('Active Orders'), findsOneWidget);
      expect(find.text('Item Summary'), findsOneWidget);

      // Active orders badge should show 2 (since 2 orders are pending)
      expect(find.text('2'), findsWidgets);
    },
  );

  testWidgets(
    'StallPosScreen expandable categories collapse and expand without resetting cart',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Add Masala Chai to cart
      await tester.tap(find.text('Masala Chai'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets); // In-cart quantity badge

      // Find Beverages category ExpansionTile and tap its header to collapse
      await tester.tap(find.text('Beverages').first);
      await tester.pumpAndSettle();

      // Tap header again to expand
      await tester.tap(find.text('Beverages').first);
      await tester.pumpAndSettle();

      // Cart quantity should still be 1!
      expect(find.text('1'), findsWidgets);
      expect(find.text('PUNCH ORDER (#103) • ₹20'), findsOneWidget);

      // Now collapse again and switch tabs to reproduce the bug
      await tester.tap(find.text('Beverages').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('POS / Register'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'POS takes order with customer name and Payment dialog confirms payment from Active Orders',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Add Veg Samosa (₹25)
      await tester.tap(find.text('Veg Samosa'));
      await tester.pumpAndSettle();

      // Enter optional customer name in cart
      final nameField = find.widgetWithText(
        TextField,
        'Customer Name (Optional)',
      );
      await tester.enterText(nameField, 'Ananya');
      await tester.pumpAndSettle();

      // Tap checkout in POS (order placed directly without popup dialog)
      await tester.tap(find.text('PUNCH ORDER (#103) • ₹25'));
      await tester.pumpAndSettle();

      // SnackBar confirms order placed (payment pending)
      expect(find.text('Order #103 placed! Payment pending.'), findsOneWidget);

      // Switch to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // Order #103 appears in "To Confirm Payment" section with category tag
      expect(find.text('To Confirm Payment'), findsOneWidget);
      expect(find.text('#103'), findsOneWidget);
      expect(find.text('Payment Pending'), findsOneWidget);
      expect(find.text('Snacks'), findsWidgets); // Category pill for Samosa

      // Tap "Confirm Payment" button on Order #103
      await tester.tap(find.byKey(const ValueKey('confirm_payment_btn_103')));
      await tester.pumpAndSettle();

      // Payment dialog should be open
      expect(find.text('Order #103'), findsOneWidget);
      expect(find.text('Total Due'), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Ananya'),
        ),
        findsOneWidget,
      );

      // Payment method selector: Cash and UPI only
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('UPI / QR'), findsOneWidget);
      expect(find.text('Card'), findsNothing);

      // Verify change calculation: by default exact (25), change 0
      expect(find.text('Change to Return:'), findsOneWidget);
      expect(find.text('₹0'), findsOneWidget);

      // Enter amount received: ₹50
      final receivedField = find.widgetWithText(
        TextField,
        'Amount Received (₹)',
      );
      await tester.enterText(receivedField, '50');
      await tester.pumpAndSettle();

      // Change should now be ₹25
      expect(find.text('₹25'), findsWidgets);

      // Tap Confirm Payment & Complete
      await tester.tap(find.text('Confirm Payment & Complete'));
      await tester.pumpAndSettle();

      // SnackBar should confirm payment
      expect(
        find.text('Payment confirmed for Order #103 via Cash!'),
        findsOneWidget,
      );

      // Order #103 has moved to Confirmed Payment Orders
      expect(find.text('Paid • Cash'), findsWidgets);
    },
  );

  testWidgets(
    'Active Orders tab shows customer name, categories, edit order, and delete order',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Switch to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // Verify Order #101 shows customer name 'Vikram' and category tag 'Beverages'
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Vikram'), findsOneWidget);
      expect(find.text('Beverages'), findsWidgets);

      // Verify Order #102 shows fallback 'Walk-in Customer' and categories
      expect(find.text('#102'), findsOneWidget);
      expect(find.text('Walk-in Customer'), findsOneWidget);
      expect(find.text('Snacks'), findsWidgets);

      // Test Delete Order #102
      final deleteButtons = find.byTooltip('Delete Order');
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Delete Order #102?'), findsOneWidget);
      expect(
        find.text('Delete Order #102? This action cannot be undone.'),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('#102'), findsOneWidget); // Still there

      // Tap Delete again and confirm
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('#102'), findsNothing);
      expect(find.text('Order #102 deleted.'), findsOneWidget);

      // Test Edit Order #101
      final editButton = find.byTooltip('Edit Order').first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Navigates back to POS screen with cart filled and editing banner
      expect(find.text('Editing Order #101'), findsWidgets);
      expect(find.text('Customer Name (Optional)'), findsWidgets);
      expect(find.text('Vikram'), findsOneWidget);
      expect(find.text('Update Order #101 • ₹40'), findsOneWidget);

      // Add a Samosa while editing
      await tester.tap(find.text('Veg Samosa'));
      await tester.pumpAndSettle();
      expect(find.text('Update Order #101 • ₹65'), findsOneWidget);

      // Allow editing snackbar to dismiss
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap Update Order button (updates order directly without popup dialog)
      await tester.tap(find.text('Update Order #101 • ₹65'));
      await tester.pumpAndSettle();

      expect(find.text('Order #101 updated!'), findsOneWidget);
      expect(find.text('TAP ITEMS TO START (#103)'), findsOneWidget);
    },
  );

  testWidgets('Item Summary tab displays consolidated item preparation queue', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
    await tester.pumpAndSettle();

    // Switch to Item Summary tab
    await tester.tap(find.text('Item Summary'));
    await tester.pumpAndSettle();

    // Order #101 has 2x Chai. Order #102 has 1x Chai and 2x Samosa.
    // Total Chai: 3 (x3)
    // Total Samosa: 2 (x2)
    expect(find.text('x3'), findsOneWidget);
    expect(find.text('x2'), findsOneWidget);

    // Ticket badges
    expect(find.text('#101 (2)'), findsOneWidget);
    expect(find.text('#102 (1)'), findsOneWidget);
    expect(find.text('#102 (2)'), findsOneWidget);
  });

  testWidgets('Theme toggle switches between Light and Dark mode', (
    WidgetTester tester,
  ) async {
    await ThemeController.instance.init();
    expect(ThemeController.instance.themeMode, ThemeMode.light);

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: ThemeController.instance,
        builder: (context, _) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeController.instance.themeMode,
            home: const StallPosScreen(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify Light theme is active initially
    expect(ThemeController.instance.isDark, isFalse);
    expect(find.byTooltip('Switch to Dark Theme'), findsOneWidget);

    // Tap theme toggle button
    await tester.tap(find.byTooltip('Switch to Dark Theme'));
    await tester.pumpAndSettle();

    // Now in dark mode
    expect(ThemeController.instance.isDark, isTrue);
    expect(find.byTooltip('Switch to Light Theme'), findsOneWidget);

    // Tap back to Light theme
    await tester.tap(find.byTooltip('Switch to Light Theme'));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.isDark, isFalse);
    expect(find.byTooltip('Switch to Dark Theme'), findsOneWidget);
  });

  testWidgets(
    'Cart BottomSheet displays items with category in brackets, steppers, and punches order',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Tap on Masala Chai to add to cart
      await tester.tap(find.text('Masala Chai'));
      await tester.pumpAndSettle();

      // Verify cart preview bar is visible
      expect(find.text('Items in Cart (1)'), findsOneWidget);
      expect(find.text('View Cart'), findsOneWidget);
      expect(find.textContaining('(Beverages)'), findsWidgets);

      // Tap 'View Cart' to open BottomSheet
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      // Verify BottomSheet contents
      expect(find.text('Cart (1 item)'), findsOneWidget);
      expect(find.text('₹20 each'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);

      // Increment quantity via stepper in bottomsheet
      final stepperAdd = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.add),
      );
      await tester.tap(stepperAdd);
      await tester.pumpAndSettle();

      // Quantity should be 2, total payable should be 40
      expect(find.text('Cart (2 items)'), findsOneWidget);
      expect(find.text('₹40'), findsWidgets);

      // Punch order from bottomsheet
      final sheetPunchButton = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('PUNCH ORDER (#103) • ₹40'),
      );
      await tester.tap(sheetPunchButton);
      await tester.pumpAndSettle();

      // Verify sheet closed and order placed
      expect(find.text('Cart (2 items)'), findsNothing);
      expect(find.text('TAP ITEMS TO START (#104)'), findsOneWidget);
    },
  );
}

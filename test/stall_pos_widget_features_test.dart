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
      await tester.tap(find.text('Masala Chai (Beverages)'));
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
      await tester.tap(find.text('Veg Samosa (Snacks)'));
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

      // Order #103 appears in "To Confirm Payment" section with category tag in brackets
      expect(find.text('To Confirm Payment'), findsOneWidget);
      expect(find.text('#103'), findsOneWidget);
      expect(find.text('Payment Pending'), findsOneWidget);
      expect(find.textContaining('Snacks'), findsWidgets);

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

      // Verify that UPI / QR is selected by default
      expect(find.textContaining('Scan UPI QR on stall terminal'), findsOneWidget);

      // Select Cash to test cash calculation
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();

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

      // Verify Order #101 shows customer name 'Vikram' and category in brackets
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('Vikram'), findsOneWidget);
      expect(find.textContaining('Beverages'), findsWidgets);

      // Verify Order #102 shows fallback 'Walk-in Customer' and category in brackets
      expect(find.text('#102'), findsOneWidget);
      expect(find.text('Walk-in Customer'), findsOneWidget);
      expect(find.textContaining('Snacks'), findsWidgets);

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
      await tester.tap(find.text('Veg Samosa (Snacks)'));
      await tester.pumpAndSettle();
      expect(find.text('Update Order #101 • ₹65'), findsOneWidget);

      // Allow editing snackbar to dismiss
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap Update Order button (now prompts for additional payment of ₹25 difference)
      await tester.tap(find.text('Update Order #101 • ₹65'));
      await tester.pumpAndSettle();

      // Additional payment dialog opens with breakdown
      expect(find.text('Previously Paid:'), findsOneWidget);
      expect(find.text('₹40'), findsWidgets);
      expect(find.text('Additional Due'), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);

      // Confirm ₹25 payment via default UPI
      await tester.tap(find.text('Confirm ₹25 & Update'));
      await tester.pumpAndSettle();

      expect(find.text('Order #101 updated! Additional ₹25 paid via UPI!'), findsOneWidget);
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

  testWidgets(
    'Item Summary tab: tapping ticket chip completes item for that order and decreases count',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Switch to Item Summary tab
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      // Initially Chai has total x3 (#101 (2), #102 (1))
      expect(find.text('x3'), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket_chip_item_1_101')), findsOneWidget);

      // Tap #101 (2) chip for Masala Chai
      await tester.tap(find.byKey(const ValueKey('ticket_chip_item_1_101')));
      await tester.pumpAndSettle();

      // Chai total drops from 3 to 1 (only #102 remains)
      expect(find.text('x1'), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket_chip_item_1_101')), findsNothing);
      expect(find.text('Order #101 completed! (Masala Chai x2)'), findsOneWidget);

      // Switch to Active Orders: Order #101 was auto-completed and is gone!
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();
      expect(find.text('#101'), findsNothing);
      expect(find.text('#102'), findsOneWidget);
    },
  );

  testWidgets(
    'Item Summary tab: tapping All Done batch completes item across tickets',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Switch to Item Summary tab
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      // Tap All Done on Masala Chai
      await tester.tap(find.byKey(const ValueKey('complete_btn_item_1')));
      await tester.pumpAndSettle();

      // Masala Chai is completely cleared from Item Summary!
      expect(find.text('Masala Chai (Hot Drinks)'), findsNothing);
      // Only Veg Samosa remains (x2)
      expect(find.text('x2'), findsOneWidget);
    },
  );

  testWidgets(
    'Active Orders tab: tapping Done button marks order completed directly',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Switch to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      expect(find.text('#101'), findsOneWidget);
      expect(find.byKey(const ValueKey('complete_order_btn_101')), findsOneWidget);

      // Tap Done on Order #101
      await tester.tap(find.byKey(const ValueKey('complete_order_btn_101')));
      await tester.pumpAndSettle();

      expect(find.text('Order #101 marked completed!'), findsOneWidget);
      // Order #101 is gone from Active Orders
      expect(find.text('#101'), findsNothing);
      expect(find.text('#102'), findsOneWidget);
    },
  );

  testWidgets(
    'Active Orders tab: tapping item toggles completion and completes order when all items are ready',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Switch to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // Order #101 only has 1 item (2x Masala Chai). Tapping it marks it ready and completes the order!
      await tester.tap(find.byKey(const ValueKey('order_101_item_item_1')));
      await tester.pumpAndSettle();

      expect(find.text('Order #101 marked completed!'), findsOneWidget);
      expect(find.text('#101'), findsNothing);
      expect(find.text('#102'), findsOneWidget);
    },
  );

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
      await tester.tap(find.text('Masala Chai (Beverages)'));
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

  testWidgets(
    'Tapping an item with slash opens variant selection sheet and adds chosen variant',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_combo',
            'name': 'Tea / Coffee',
            'price': 25.0,
            'category': 'Beverages',
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 101,
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Tea / Coffee (Beverages)'), findsOneWidget);
      // Requirement: Do not show the options UI badge on the screen for each item
      expect(find.text('Options'), findsNothing);

      // Tap the card
      await tester.tap(find.text('Tea / Coffee (Beverages)'));
      await tester.pumpAndSettle();

      // BottomSheet should open with options
      expect(find.text('Select Option'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);

      // Tap 'Coffee'
      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      // BottomSheet closed and cart has Coffee
      expect(find.text('Select Option'), findsNothing);
      expect(find.text('PUNCH ORDER (#101) • ₹25'), findsOneWidget);
      expect(find.textContaining('Coffee'), findsWidgets);
    },
  );

  testWidgets(
    'Add-ons cannot be added alone, must be linked to a main item',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_burger',
            'name': 'Veg Burger',
            'price': 80.0,
            'category': 'Fast Food',
          },
          {
            'id': 'item_cheese',
            'name': 'Extra Cheese',
            'price': 20.0,
            'category': 'Addons',
            'isAddon': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 101,
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      expect(find.text('+ Add-on'), findsNothing);

      // 1. Try tapping Add-on with empty cart -> blocked
      await tester.tap(find.text('Extra Cheese (Addons)'));
      await tester.pump();

      expect(
        find.text(
          'Add-ons must be linked to an item. Please add a main item first.',
        ),
        findsOneWidget,
      );
      expect(find.text('TAP ITEMS TO START (#101)'), findsOneWidget);

      // Wait for snackbar to dismiss
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 2. Add main item (Veg Burger)
      await tester.tap(find.text('Veg Burger (Fast Food)'));
      await tester.pumpAndSettle();

      expect(find.text('PUNCH ORDER (#101) • ₹80'), findsOneWidget);

      // 3. Tap Add-on now -> links to the single item
      await tester.tap(find.text('Extra Cheese (Addons)'));
      await tester.pumpAndSettle();

      // Cart total should now be 80 + 20 = 100
      expect(find.text('PUNCH ORDER (#101) • ₹100'), findsOneWidget);

      // Open cart bottom sheet and verify item name has bracketed prefix
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      expect(find.text('[Extra Cheese] Veg Burger (Fast Food)'), findsOneWidget);
      expect(find.text('₹100 each'), findsOneWidget);

      // Verify money split between item and addons
      expect(find.text('Split: Item ₹80 + Add-on ₹20'), findsOneWidget);
      expect(find.text('Extra Cheese (+₹20)'), findsOneWidget);
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('Add-ons Subtotal'), findsOneWidget);
      expect(find.text('+₹20'), findsOneWidget);
    },
  );

  testWidgets(
    'Centralized slash selection modal keeps Rice / Noodles category intact in UI and prompts for category when clicked',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_combo',
            'name': 'Fried Rice / Hakka Noodles',
            'price': 120.0,
            'category': 'Rice / Noodles',
          },
          {
            'id': 'item_pure_cat',
            'name': 'Schezwan Platter',
            'price': 130.0,
            'category': 'Rice / Noodles',
          },
          {
            'id': 'item_addon_cm',
            'name': 'Cheese / Mayo',
            'price': 25.0,
            'category': 'Addons',
            'isAddon': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 101,
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // 1. Verify category chip is intact as 'Rice / Noodles' (NOT split into 'Rice' and 'Noodles')
      expect(find.widgetWithText(ChoiceChip, 'Rice / Noodles'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Rice'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Noodles'), findsNothing);

      // 2. Tap item with category 'Rice / Noodles' (Schezwan Platter)
      await tester.tap(find.text('Schezwan Platter (Rice / Noodles)').first);
      await tester.pumpAndSettle();

      // Modal appears asking which category in Rice / Noodles!
      expect(find.text('Select Category'), findsOneWidget);
      expect(find.text('SELECT CATEGORY'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Rice')), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Noodles')), findsOneWidget);

      // Tap 'Rice' inside modal (single-tap fast-path adds Schezwan Platter (Rice) to cart and dismisses)
      await tester.tap(find.byKey(const ValueKey('cat_choice_Rice')));
      await tester.pumpAndSettle();

      expect(find.text('PUNCH ORDER (#101) • ₹130'), findsOneWidget);

      // 3. Tap Addon with slash in name (Cheese / Mayo)
      await tester.tap(find.text('Cheese / Mayo (Addons)'));
      await tester.pumpAndSettle();

      // Modal appears for addon with variants & quantity steppers
      expect(find.text('Customize Extra'), findsOneWidget);
      expect(find.text('CHOOSE EXTRAS & QUANTITIES'), findsOneWidget);
      expect(find.text('Cheese'), findsOneWidget);
      expect(find.text('Mayo'), findsOneWidget);

      // Increment Cheese to 2x
      final addButtons = find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.add));
      await tester.tap(addButtons.first); // Cheese +
      await tester.pumpAndSettle();

      // Verify button reflects 2x Cheese
      expect(find.textContaining('2x Cheese'), findsOneWidget);

      // Tap confirmation button
      await tester.tap(find.textContaining('Add [2x Cheese] to Schezwan Platter (Rice)'));
      await tester.pumpAndSettle();

      // Cart total should now be 130 + 25*2 = 180
      expect(find.text('PUNCH ORDER (#101) • ₹180'), findsOneWidget);

      // 4. Open cart bottom sheet and verify centralized displayName with [2x Cheese] and resolved category (Rice)
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      final cartItemText = tester.widget<Text>(find.text('[2x Cheese] Schezwan Platter (Rice)'));
      expect(cartItemText.overflow, isNull);
      expect(cartItemText.maxLines, isNull);

      expect(find.text('[2x Cheese] Schezwan Platter (Rice)'), findsOneWidget);
      expect(find.text('₹180 each'), findsOneWidget);
      expect(find.text('Split: Item ₹130 + Add-ons ₹50'), findsOneWidget);
      expect(find.text('2x Cheese (+₹50)'), findsOneWidget);
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('Add-ons Subtotal'), findsOneWidget);
      expect(find.text('+₹50'), findsOneWidget);

      // 5. Punch order and verify on Active Orders
      await tester.tap(find.text('PUNCH ORDER (#101) • ₹180').first, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      expect(find.text('[2x Cheese] Schezwan Platter (Rice)'), findsOneWidget);
      final activeItemText = tester.widget<Text>(find.text('[2x Cheese] Schezwan Platter (Rice)'));
      expect(activeItemText.overflow, isNull);
      expect(activeItemText.maxLines, isNull);

      // 6. Confirm payment via default UPI (1-tap complete)
      await tester.tap(find.byKey(const ValueKey('confirm_payment_btn_101')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan UPI QR on stall terminal'), findsOneWidget);
      await tester.tap(find.text('Confirm Payment & Complete'));
      await tester.pumpAndSettle();

      expect(find.text('Payment confirmed for Order #101 via UPI!'), findsOneWidget);
      expect(find.text('Paid • UPI'), findsWidgets);

      // 7. Verify in Item Summary tab that item name is fully visible
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      expect(find.text('[2x Cheese] Schezwan Platter (Rice)'), findsOneWidget);
      final summaryItemText = tester.widget<Text>(find.text('[2x Cheese] Schezwan Platter (Rice)'));
      expect(summaryItemText.overflow, isNull);
    },
  );

  testWidgets(
    'Editing paid order with added items and choosing Pay Later keeps new item out of confirmed payment until paid',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Go to Active Orders and edit Order #101 (originally ₹40 paid for 2x Chai)
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      final editBtn = find.byTooltip('Edit Order').first;
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Add a Veg Samosa (₹25)
      await tester.tap(find.text('Veg Samosa (Snacks)'));
      await tester.pumpAndSettle();

      // Allow editing snackbar to dismiss
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap Update Order #101 • ₹65
      await tester.tap(find.text('Update Order #101 • ₹65'));
      await tester.pumpAndSettle();

      // Additional payment dialog appears
      expect(find.text('Update Order #101'), findsOneWidget);
      expect(find.text('Previously Paid:'), findsOneWidget);
      expect(find.text('₹40'), findsWidgets);
      expect(find.text('Additional Due'), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);

      // Tap Pay Later (Pending)
      await tester.tap(find.text('Pay Later (Pending)'));
      await tester.pumpAndSettle();

      expect(find.text('Order #101 updated! Additional ₹25 pending.'), findsOneWidget);

      // Go to Active Orders
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // Order #101 must NOT be in Confirmed Payment Orders!
      // It must be in "To Confirm Payment" section!
      expect(find.text('₹25 Due • Paid ₹40'), findsOneWidget);
      expect(find.text('Extra • Pending'), findsOneWidget);

      // Check Item Summary tab: Veg Samosa must NOT be in Item Summary yet!
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      // 2x Chai was already paid, so it remains in Item Summary
      expect(find.text('Masala Chai (Beverages)'), findsOneWidget);
      // Veg Samosa from Order #101 is NOT paid yet, so ticket #101 (1) must NOT appear in Item Summary!
      expect(find.text('#101 (1)'), findsNothing);
      expect(find.text('#102 (2)'), findsOneWidget);

      // Now go back to Active Orders and tap "Confirm ₹25"
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm ₹25'));
      await tester.pumpAndSettle();

      // Payment confirmation dialog opens for the remaining ₹25
      expect(find.text('₹25'), findsWidgets);
      await tester.tap(find.text('Confirm ₹25 & Update'));
      await tester.pumpAndSettle();

      expect(find.text('Payment confirmed for Order #101 via UPI!'), findsOneWidget);

      // Order #101 is now in Confirmed Payment Orders!
      expect(find.text('Paid • UPI'), findsWidgets);
      expect(find.text('Extra • Pending'), findsNothing);

      // Check Item Summary tab again: Veg Samosa from #101 is NOW present!
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      expect(find.text('#101 (1)'), findsOneWidget);
      expect(find.text('#102 (2)'), findsOneWidget);
    },
  );

  testWidgets(
    'Editing paid order by linking an addon item moves the linked item to confirm payment while paid item stays in confirmed payment',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_b1',
            'name': 'Veg Burger',
            'price': 50.0,
            'category': 'Fast Food',
          },
          {
            'id': 'item_c1',
            'name': 'Extra Cheese',
            'price': 20.0,
            'category': 'Addons',
            'isAddon': true,
          },
          {
            'id': 'item_c2',
            'name': 'Masala Chai',
            'price': 20.0,
            'category': 'Beverages',
          },
        ]),
        'stall_orders': jsonEncode([
          {
            'token': 101,
            'itemsSummary': '1x Veg Burger, 1x Masala Chai',
            'total': 70.0,
            'timestamp': DateTime.now().toIso8601String(),
            'customerName': 'Aman',
            'isPaid': true,
            'paidAmount': 70.0,
            'paymentMethod': 'UPI',
            'items': {'item_b1': 1, 'item_c2': 1},
            'paidItems': {'item_b1': 1, 'item_c2': 1},
          }
        ]),
        'stall_next_token': 102,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: StallPosScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // Confirmed Payment Orders has Order #101
      expect(find.text('Confirmed Payment Orders'), findsOneWidget);
      expect(find.text('#101'), findsOneWidget);

      // Edit Order #101
      await tester.tap(find.byTooltip('Edit Order'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // We are now on Menu/Cart tab editing Order #101
      expect(find.text('Editing Order #101'), findsWidgets);

      // Tap Extra Cheese add-on item in menu
      await tester.tap(find.text('Extra Cheese (Addons)'));
      await tester.pumpAndSettle();

      // Add-on selection modal opens; confirm adding Extra Cheese to Veg Burger
      expect(find.text('Customize Extra'), findsOneWidget);
      await tester.tap(find.textContaining('Add [Extra Cheese]'));
      await tester.pumpAndSettle();

      // Now cart has [Extra Cheese] Veg Burger + Masala Chai (Total ₹90)
      expect(find.text('Update Order #101 • ₹90'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap Update Order #101 • ₹90
      await tester.tap(find.text('Update Order #101 • ₹90'));
      await tester.pumpAndSettle();

      // Additional payment dialog opens (Additional Due ₹20)
      expect(find.text('Additional Due'), findsOneWidget);
      expect(find.text('₹20'), findsWidgets);

      // Choose Pay Later (Pending)
      await tester.tap(find.text('Pay Later (Pending)'));
      await tester.pumpAndSettle();

      // Go to Active Orders tab
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      // In Confirmed Payment Orders: Order #101 is present showing Masala Chai!
      // In To Confirm Payment: Order #101 is present showing [Extra Cheese] Veg Burger!
      expect(find.text('Confirmed Payment Orders'), findsOneWidget);
      expect(find.text('To Confirm Payment'), findsOneWidget);
      expect(find.text('₹20 Due • Paid ₹70'), findsOneWidget);
      expect(find.text('Confirm ₹20'), findsOneWidget);

      // Go to Item Summary tab: Only Masala Chai from Confirmed Payment Orders is shown!
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Masala Chai (Beverages)'), findsOneWidget);
      // [Extra Cheese] Veg Burger must NOT be in Item Summary because it is in To Confirm Payment!
      expect(find.textContaining('Veg Burger'), findsNothing);

      // Go back to Active Orders and confirm the remaining ₹20
      await tester.tap(find.text('Active Orders'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm ₹20'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm ₹20 & Update'));
      await tester.pumpAndSettle();

      // Now Order #101 is fully paid and in Confirmed Payment Orders only!
      expect(find.text('To Confirm Payment'), findsOneWidget);
      expect(find.text('Confirm ₹20'), findsNothing);

      // Check Item Summary: Now [Extra Cheese] Veg Burger IS in Item Summary!
      await tester.tap(find.text('Item Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Masala Chai (Beverages)'), findsOneWidget);
      expect(find.textContaining('Veg Burger'), findsOneWidget);
    },
  );

  testWidgets(
    'Mobile web category card rendering below first card has no errors and no Options UI badge',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'r1',
            'name': 'Veg Manchuria',
            'price': 130.0,
            'category': 'Rolls',
          },
          {
            'id': 'r2',
            'name': 'Paneer',
            'price': 150.0,
            'category': 'Rolls',
          },
          {
            'id': 's1',
            'name': 'Veg Manchuria',
            'price': 150.0,
            'category': 'Starters',
          },
          {
            'id': 's2',
            'name': 'Chilli / Paneer 65',
            'price': 200.0,
            'category': 'Starters',
          },
          {
            'id': 'rn1',
            'name': 'Veg',
            'price': 170.0,
            'category': 'Rice/Noodles',
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 1,
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // Verify no ErrorWidget anywhere on screen
      expect(find.byType(ErrorWidget), findsNothing);

      // Verify Category headers are displayed
      expect(find.text('Rolls'), findsWidgets);
      expect(find.text('Starters'), findsWidgets);
      expect(find.text('Rice/Noodles'), findsWidgets);

      // Verify items in the first card (Rolls)
      expect(find.text('Veg Manchuria (Rolls)'), findsOneWidget);
      expect(find.text('Paneer (Rolls)'), findsOneWidget);

      // Verify items in the second card below first card (Starters)
      expect(find.text('Veg Manchuria (Starters)'), findsOneWidget);
      expect(find.text('Chilli / Paneer 65 (Starters)'), findsOneWidget);

      // Verify requirement: Options badge is NOT shown on the screen for items with slash variants
      expect(find.text('Options'), findsNothing);

      // Verify collapsing and expanding the category card
      await tester.tap(find.text('Starters').first);
      await tester.pumpAndSettle();

      // Tapping again expands
      await tester.tap(find.text('Starters').first);
      await tester.pumpAndSettle();
      expect(find.text('Chilli / Paneer 65 (Starters)'), findsOneWidget);
    },
  );

  testWidgets(
    'Limits each add-on item to a maximum of 2 and allows multiple add-on types',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'stall_menu': jsonEncode([
          {
            'id': 'item_burger',
            'name': 'Veg Burger',
            'price': 80.0,
            'category': 'Fast Food',
          },
          {
            'id': 'item_cheese',
            'name': 'Extra Cheese',
            'price': 20.0,
            'category': 'Addons',
            'isAddon': true,
          },
          {
            'id': 'item_mayo',
            'name': 'Mayo',
            'price': 15.0,
            'category': 'Addons',
            'isAddon': true,
          },
        ]),
        'stall_orders': jsonEncode([]),
        'stall_next_token': 101,
      });

      await tester.pumpWidget(const MaterialApp(home: StallPosScreen()));
      await tester.pumpAndSettle();

      // 1. Add Veg Burger to cart
      await tester.tap(find.text('Veg Burger (Fast Food)').first);
      await tester.pumpAndSettle();

      // 2. Add first cheese (count: 1)
      await tester.tap(find.text('Extra Cheese (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.text('Added [Extra Cheese] to Veg Burger (Fast Food)'), findsOneWidget);

      // 3. Add second cheese (count: 2)
      await tester.tap(find.text('Extra Cheese (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Added [Extra Cheese] to'), findsOneWidget);

      // 4. Try to add third cheese (blocked by max 2 limit for Extra Cheese)
      await tester.tap(find.text('Extra Cheese (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.text('Maximum 2 [Extra Cheese] already added to items in cart.'), findsOneWidget);

      // 5. Add first Mayo (count: 1) - allowed because limit is per addon item!
      await tester.tap(find.text('Mayo (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Added [Mayo] to'), findsOneWidget);

      // 6. Add second Mayo (count: 2)
      await tester.tap(find.text('Mayo (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Added [Mayo] to'), findsOneWidget);

      // 7. Try to add third Mayo (blocked by max 2 limit for Mayo)
      await tester.tap(find.text('Mayo (Addons)').first);
      await tester.pumpAndSettle();
      expect(find.text('Maximum 2 [Mayo] already added to items in cart.'), findsOneWidget);

      // 8. Open Review Cart bottom sheet
      await tester.tap(find.text('View Cart'));
      await tester.pumpAndSettle();

      // Verify Review Cart displays 'Max Extras (2/2)' badge because all available add-ons are maxed out
      expect(find.text('Max Extras (2/2)'), findsOneWidget);
      expect(find.text('+ Extras / Add-on'), findsNothing);
      expect(find.text('Split: Item ₹80 + Add-ons ₹70'), findsOneWidget);
      expect(find.textContaining('2x Extra Cheese (+₹40)'), findsOneWidget);
      expect(find.textContaining('2x Mayo (+₹30)'), findsOneWidget);
    },
  );
}


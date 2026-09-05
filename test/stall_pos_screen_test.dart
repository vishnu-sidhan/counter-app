import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/screens/stall_pos_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StallPosScreen starts empty and handles adding items to cart', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and empty menu state
    expect(find.text('⚡ StallPOS'), findsOneWidget);
    expect(find.text('No menu items yet'), findsOneWidget);
    expect(find.text('Tap + in the top bar to add your first item'), findsOneWidget);

    // Initial button state when cart is empty
    expect(find.text('TAP ITEMS TO START (#1)'), findsOneWidget);

    // Add a menu item with category via dialog
    await tester.tap(find.byTooltip('Add Menu Item'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Veg Roll');
    await tester.enterText(textFields.at(1), '80');
    await tester.enterText(textFields.at(2), 'Snacks');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();

    expect(find.text('Veg Roll'), findsOneWidget);
    expect(find.text('₹80'), findsOneWidget);
    expect(find.text('Snacks'), findsWidgets);

    // Tap on 'Veg Roll' to add to cart
    await tester.tap(find.text('Veg Roll'));
    await tester.pumpAndSettle();

    // Verify cart count badge (1) and button updated
    expect(find.text('1'), findsWidgets);
    expect(find.text('PUNCH ORDER (#1) • ₹80'), findsOneWidget);

    // Tap 'Veg Roll' again
    await tester.tap(find.text('Veg Roll'));
    await tester.pumpAndSettle();

    // Verify cart total updated to 160
    expect(find.text('PUNCH ORDER (#1) • ₹160'), findsOneWidget);

    // Tap 'Clear' button
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('TAP ITEMS TO START (#1)'), findsOneWidget);
  });

  testWidgets('StallPosScreen filters by category chips', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Beverages'},
        {'id': '102', 'name': 'Veg Samosa', 'price': 25, 'category': 'Snacks'},
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Both items visible initially under 'All'
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsOneWidget);

    // Category chips visible
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beverages'), findsWidgets);
    expect(find.text('Snacks'), findsWidgets);

    // Tap 'Beverages' chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Beverages'));
    await tester.pumpAndSettle();

    // Only Masala Chai should be visible
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsNothing);

    // Tap 'Snacks' chip
    await tester.tap(find.widgetWithText(ChoiceChip, 'Snacks'));
    await tester.pumpAndSettle();

    // Only Veg Samosa should be visible
    expect(find.text('Veg Samosa'), findsOneWidget);
    expect(find.text('Masala Chai'), findsNothing);

    // Switch back to 'All'
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Veg Samosa'), findsOneWidget);
  });

  testWidgets('StallPosScreen displays category split with headings and items in UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Hot Drinks'},
        {'id': '102', 'name': 'Green Tea', 'price': 25, 'category': 'Hot Drinks'},
        {'id': '103', 'name': 'Paneer Roll', 'price': 70, 'category': 'Snacks'},
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify category headings
    expect(find.text('Hot Drinks'), findsWidgets); // chip + heading
    expect(find.text('Snacks'), findsWidgets); // chip + heading

    // Verify item count badge under Hot Drinks (2) and Snacks (1)
    expect(find.text('2'), findsWidgets);
    expect(find.text('1'), findsWidgets);

    // Verify all items are rendered under their respective sections
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Green Tea'), findsOneWidget);
    expect(find.text('Paneer Roll'), findsOneWidget);
  });

  testWidgets('StallPosScreen allows deleting a menu item via long-press', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Masala Chai', 'price': 20, 'category': 'Beverages'},
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masala Chai'), findsOneWidget);

    // Long press on Masala Chai
    await tester.longPress(find.text('Masala Chai'));
    await tester.pumpAndSettle();

    // Bottom sheet should appear with Delete option
    expect(find.text('Delete Item'), findsOneWidget);
    await tester.tap(find.text('Delete Item'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Delete Menu Item?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Menu should now be empty
    expect(find.text('Masala Chai'), findsNothing);
    expect(find.text('No menu items yet'), findsOneWidget);
  });

  testWidgets('StallPosScreen fires order and displays side-by-side on wide screens', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': '101', 'name': 'Paneer Wrap', 'price': 100, 'category': 'Snacks'},
        {'id': '102', 'name': 'Cold Coffee', 'price': 60, 'category': 'Beverages'},
      ]),
    });

    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Add Paneer Wrap and Cold Coffee
    await tester.tap(find.text('Paneer Wrap'));
    await tester.tap(find.text('Cold Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('PUNCH ORDER (#1) • ₹160'), findsOneWidget);

    // Fire the order
    await tester.tap(find.text('PUNCH ORDER (#1) • ₹160'));
    await tester.pump();

    // Cart cleared and next token is #2
    expect(find.text('TAP ITEMS TO START (#2)'), findsOneWidget);

    // On wide screen, Kitchen Queue is displayed side-by-side
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('1x Paneer Wrap, 1x Cold Coffee'), findsOneWidget);
    expect(find.text('✓ Done'), findsOneWidget);

    // Mark order as completed
    await tester.tap(find.text('✓ Done'));
    await tester.pumpAndSettle();

    // Verify queue is now all caught up
    expect(find.text('All caught up! No pending orders.'), findsOneWidget);
  });

  testWidgets('StallPosScreen navigates to Order History and back', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StallPosScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Order History AppBar icon
    await tester.tap(find.byTooltip('Order History'));
    await tester.pumpAndSettle();

    // Order History screen is displayed
    expect(find.text('Order History'), findsOneWidget);
    expect(find.byTooltip('Download CSV'), findsOneWidget);

    // Pop back
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('⚡ StallPOS'), findsOneWidget);
  });
}

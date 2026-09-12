import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_app/data/models/stall_models.dart';
import 'package:counter_app/data/storage/in_memory_storage.dart';
import 'package:counter_app/controllers/order_controller.dart';
import 'package:counter_app/widgets/stall_pos/category_accordion_card.dart';
import 'package:counter_app/widgets/stall_pos/category_config_dialog.dart';
import 'package:counter_app/widgets/stall_pos/manage_categories_dialog.dart';
import 'package:counter_app/widgets/stall_pos/cart_bottom_sheet.dart';
import 'package:counter_app/widgets/stall_pos/menu_item_card.dart';

void main() {
  group('CategoryOption Model Tests', () {
    test('serializes and deserializes CategoryOption correctly', () {
      const option = CategoryOption(
        id: 'opt_fried',
        name: 'Fried',
        additionalCost: 10.0,
        isEnabled: true,
      );

      expect(option.costBadge, '+₹10');
      final json = option.toJson();
      expect(json['id'], 'opt_fried');
      expect(json['name'], 'Fried');
      expect(json['additionalCost'], 10.0);
      expect(json['isEnabled'], isTrue);

      final fromJson = CategoryOption.fromJson(json);
      expect(fromJson, equals(option));
      expect(fromJson.hashCode, equals(option.hashCode));
    });

    test('costBadge handles decimal prices and disabled states', () {
      const decimalOpt = CategoryOption(
        id: 'opt_pan',
        name: 'Pan Fried',
        additionalCost: 15.5,
        isEnabled: true,
      );
      expect(decimalOpt.costBadge, '+₹15.50');

      const zeroOpt = CategoryOption(
        id: 'opt_steam',
        name: 'Steam',
        additionalCost: 0.0,
      );
      expect(zeroOpt.costBadge, '');

      const disabledOpt = CategoryOption(
        id: 'opt_tandoori',
        name: 'Tandoori',
        additionalCost: 20.0,
        isEnabled: false,
      );
      expect(disabledOpt.costBadge, '');
    });
  });

  group('ItemCategory Model Tests', () {
    test('serializes and deserializes ItemCategory correctly', () {
      const category = ItemCategory(
        id: 'cat_beverages',
        name: 'Beverages',
        additionalCost: 5.0,
        costReason: 'Packaging Fee',
        colorHex: 0xFF1D4ED8,
        isPerItem: true,
        isEnabled: true,
      );

      expect(category.costDescription, '+₹5 Packaging Fee');
      expect(category.hasAdditionalCost, isTrue);

      final json = category.toJson();
      expect(json['id'], 'cat_beverages');
      expect(json['name'], 'Beverages');
      expect(json['additionalCost'], 5.0);
      expect(json['costReason'], 'Packaging Fee');
      expect(json['colorHex'], 0xFF1D4ED8);

      final fromJson = ItemCategory.fromJson(json);
      expect(fromJson, equals(category));
      expect(fromJson.hashCode, equals(category.hashCode));
    });

    test('auto-derives effectiveOptions from slash in category name', () {
      const momosCategory = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
      );

      expect(momosCategory.hasOptions, isTrue);
      expect(momosCategory.options, isEmpty);
      final derived = momosCategory.effectiveOptions;
      expect(derived.length, 3);
      expect(derived[0].name, 'Steam');
      expect(derived[1].name, 'Fried');
      expect(derived[2].name, 'Pan Fried');
    });

    test('costDescription summarizes multiple CategoryOptions correctly', () {
      const momosCategory = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_pan', name: 'Pan Fried', additionalCost: 20.0),
        ],
      );

      expect(momosCategory.hasAdditionalCost, isTrue);
      expect(momosCategory.costDescription, 'Fried (+₹10), Pan Fried (+₹20)');
      expect(momosCategory.getOptionCost('Steam'), 0.0);
      expect(momosCategory.getOptionCost('Fried'), 10.0);
      expect(momosCategory.getOptionCost('Pan Fried'), 20.0);
      expect(momosCategory.getOptionCost('NonExistent'), 0.0);
    });

    test('costDescription returns empty when additionalCost is 0 or disabled', () {
      const zeroCost = ItemCategory(
        id: 'cat_snacks',
        name: 'Snacks',
        additionalCost: 0.0,
      );
      expect(zeroCost.costDescription, '');
      expect(zeroCost.hasAdditionalCost, isFalse);

      const disabledCost = ItemCategory(
        id: 'cat_meals',
        name: 'Meals',
        additionalCost: 15.0,
        costReason: 'Container Charge',
        isEnabled: false,
      );
      expect(disabledCost.costDescription, '');
      expect(disabledCost.hasAdditionalCost, isFalse);
    });

    test('copyWith updates fields as expected', () {
      const original = ItemCategory(
        id: 'cat_1',
        name: 'Desserts',
        additionalCost: 10.0,
        costReason: 'Cold Box',
      );

      final updated = original.copyWith(
        additionalCost: 15.0,
        clearCostReason: true,
      );

      expect(updated.additionalCost, 15.0);
      expect(updated.costReason, isNull);
      expect(updated.costDescription, '+₹15');
    });

    test('MenuItem supports custom displayName, serialization, and copyWith', () {
      const itemWithCustom = MenuItem(
        id: 'item_1',
        name: 'Veg Steamed Momos',
        displayName: 'Momos',
        category: 'Momos',
        price: 80,
      );
      expect(itemWithCustom.displayName, 'Momos (Momos)');
      expect(itemWithCustom.customDisplayName, 'Momos');

      const itemWithoutCustom = MenuItem(
        id: 'item_2',
        name: 'Veg Steamed Momos',
        price: 80,
      );
      expect(itemWithoutCustom.displayName, 'Veg Steamed Momos (General)');
      expect(itemWithoutCustom.customDisplayName, isNull);

      const itemWithBlank = MenuItem(
        id: 'item_3',
        name: 'Veg Steamed Momos',
        displayName: '   ',
        price: 80,
      );
      expect(itemWithBlank.displayName, 'Veg Steamed Momos (General)');

      final copied = itemWithCustom.copyWith(price: 90);
      expect(copied.displayName, 'Momos (Momos)');
      expect(copied.price, 90);

      final cleared = itemWithCustom.copyWith(clearDisplayName: true);
      expect(cleared.customDisplayName, isNull);
      expect(cleared.displayName, 'Veg Steamed Momos (Momos)');

      final json = itemWithCustom.toJson();
      expect(json['displayName'], 'Momos');
      final fromJson = MenuItem.fromJson(json);
      expect(fromJson.customDisplayName, 'Momos');
      expect(fromJson.displayName, 'Momos (Momos)');
    });
  });

  group('OrderController Category Additional Cost Logic', () {
    late InMemoryStallStorage storage;
    late OrderController controller;

    final sampleMenu = [
      const MenuItem(
        id: 'item_chai',
        name: 'Masala Chai',
        price: 20.0,
        category: 'Beverages',
      ),
      const MenuItem(
        id: 'item_samosa',
        name: 'Veg Samosa',
        price: 25.0,
        category: 'Snacks',
      ),
      const MenuItem(
        id: 'item_momos',
        name: 'Veg Momos',
        price: 60.0,
        category: 'Steam / Fried / Pan Fried',
      ),
      const MenuItem(
        id: 'addon_ginger',
        name: 'Extra Ginger',
        price: 5.0,
        category: 'Addon',
        isAddon: true,
        linkedCategory: 'Beverages',
      ),
    ];

    setUp(() async {
      storage = InMemoryStallStorage(initialMenu: sampleMenu);
      controller = OrderController(storageService: storage);
      await controller.loadPersistedData();
    });

    test('auto-discovers categories from menu with default 0 cost', () {
      expect(controller.categoryConfigs.isNotEmpty, isTrue);
      expect(controller.getCategoryCost('Beverages'), 0.0);
      expect(controller.getCategoryCost('Snacks'), 0.0);
      expect(controller.getCategoryCostReason('Beverages'), isNull);
    });

    test('updates category additional cost and persists it', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Packaging Fee',
      );

      expect(controller.getCategoryCost('Beverages'), 5.0);
      expect(controller.getCategoryCostReason('Beverages'), 'Packaging Fee');

      final persisted = await storage.loadCategories();
      final bevPersisted = persisted.firstWhere((c) => c.name == 'Beverages');
      expect(bevPersisted.additionalCost, 5.0);
      expect(bevPersisted.costReason, 'Packaging Fee');
    });

    test('handles multi-category option pricing for Momos (Steam/Fried/Pan Fried)', () async {
      const momosConfig = ItemCategory(
        id: 'cat_momos',
        name: 'Steam / Fried / Pan Fried',
        options: [
          CategoryOption(id: 'opt_steam', name: 'Steam', additionalCost: 0.0),
          CategoryOption(id: 'opt_fried', name: 'Fried', additionalCost: 10.0),
          CategoryOption(id: 'opt_pan', name: 'Pan Fried', additionalCost: 20.0),
        ],
      );

      await controller.saveCategoryConfig(momosConfig);

      // Verify individual option charges resolved directly
      expect(controller.getCategoryCost('Steam'), 0.0);
      expect(controller.getCategoryCost('Fried'), 10.0);
      expect(controller.getCategoryCost('Pan Fried'), 20.0);

      // Verify resolving option from parent category
      expect(controller.getCategoryOptionCost('Steam / Fried / Pan Fried', 'Fried'), 10.0);
      expect(controller.getCategoryOptionCost('Steam / Fried / Pan Fried', 'Pan Fried'), 20.0);

      // Add Momos with 'Fried' variant to cart
      final momosItem = controller.findItem('item_momos');
      controller.addCustomizedItemToCart(
        baseItem: momosItem,
        resolvedCategory: 'Fried',
      );

      final friedCartItemId = controller.cart.keys.first;
      final friedItem = controller.findItem(friedCartItemId);
      expect(friedItem.category, 'Fried');
      final friedBreakdown = controller.getCartItemBreakdown(friedCartItemId);
      expect(friedBreakdown?.categoryAdditionalCost, 10.0);
      expect(controller.cartTotal, 70.0); // 60 base + 10 fried

      // Add Momos with 'Pan Fried' variant to cart
      controller.addCustomizedItemToCart(
        baseItem: momosItem,
        resolvedCategory: 'Pan Fried',
      );

      final panFriedCartItemId =
          controller.cart.keys.firstWhere((k) => k.contains('Pan Fried'));
      final panFriedBreakdown = controller.getCartItemBreakdown(panFriedCartItemId);
      expect(panFriedBreakdown?.categoryAdditionalCost, 20.0);
      expect(controller.cartTotal, 150.0); // (60+10) + (60+20) = 150
    });

    test('updateCategoryOptionCost helper updates specific variant charge', () async {
      await controller.updateCategoryOptionCost(
        parentCategory: 'Steam / Fried / Pan Fried',
        optionName: 'Fried',
        additionalCost: 12.0,
      );

      expect(controller.getCategoryCost('Fried'), 12.0);
    });

    test('calculates cart item category cost correctly for regular item vs addon', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 3.0,
        reason: 'Cup Charge',
      );

      final chai = controller.findItem('item_chai');
      controller.addToCart(chai);

      final chaiBreakdown = controller.getCartItemBreakdown('item_chai');
      expect(chaiBreakdown?.categoryAdditionalCost, 3.0);
      expect(chaiBreakdown?.categoryCostReason, 'Cup Charge');
      expect(controller.cartTotal, 23.0); // 20 + 3

      // Addon linked to Beverages should not get category charge
      final ginger = controller.findItem('addon_ginger');
      controller.addAddonToCart(targetCartItemId: 'item_chai', addon: ginger);

      expect(controller.cartTotal, 28.0); // 20 item + 3 cat + 5 addon
    });

    test('order snapshot preserves category additional cost in order itemsSnapshot', () async {
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 4.0,
        reason: 'Eco Packaging',
      );

      final chai = controller.findItem('item_chai');
      controller.addToCart(chai);
      final orderResult = await controller.punchOrUpdateOrder(
        customerName: 'Test',
        paymentMethod: 'Cash',
        isPaid: true,
      );

      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      expect(order.itemSnapshots['item_chai']?['categoryAdditionalCost'], 4.0);
      expect(order.itemSnapshots['item_chai']?['categoryCostReason'], 'Eco Packaging');
    });
  });

  group('Category Additional Cost Widgets Tests', () {
    testWidgets('CategoryAccordionCard renders costDescription badge and configure button',
        (tester) async {
      bool configureTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Beverages',
              items: const [
                MenuItem(id: '1', name: 'Coffee', price: 30, category: 'Beverages'),
              ],
              isExpanded: true,
              costDescription: '+₹5 Packaging',
              onConfigure: () => configureTapped = true,
              onToggle: () {},
              getCategoryColor: (_) => Colors.blue,
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );

      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('+₹5 Packaging'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      expect(configureTapped, isTrue);
    });

    testWidgets('CategoryAccordionCard renders catName as title and costDescription',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Steam / Fried / Pan Fried',
              items: const [
                MenuItem(id: '1', name: 'Veg Momos', price: 60, category: 'Steam / Fried / Pan Fried'),
              ],
              isExpanded: true,
              costDescription: 'Fried (+₹10), Pan Fried (+₹20)',
              onToggle: () {},
              getCategoryColor: (_) => Colors.deepOrange,
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );

      // Title is Steam / Fried / Pan Fried
      expect(find.text('Steam / Fried / Pan Fried'), findsOneWidget);
      expect(find.text('Fried (+₹10), Pan Fried (+₹20)'), findsOneWidget);
    });

    testWidgets('CategoryConfigDialog updates category additional cost',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(id: '1', name: 'Chai', price: 20, category: 'Beverages'),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryConfigDialog.show(
                    context,
                    categoryName: 'Beverages',
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Category: Beverages'), findsOneWidget);
      expect(find.text('Additional Cost (₹)'), findsOneWidget);

      // Enter additional cost 5
      await tester.enterText(find.widgetWithText(TextField, 'Additional Cost (₹)'), '5');
      // Tap quick suggestion chip 'Packaging Fee'
      await tester.tap(find.text('Packaging Fee'));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(controller.getCategoryCost('Beverages'), 5.0);
      expect(controller.getCategoryCostReason('Beverages'), 'Packaging Fee');
    });

    testWidgets('CategoryConfigDialog edits multi-category option charges for Momos',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: '1',
          name: 'Veg Momos',
          price: 60,
          category: 'Steam / Fried / Pan Fried',
        ),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CategoryConfigDialog.show(
                    context,
                    categoryName: 'Steam / Fried / Pan Fried',
                    controller: controller,
                    getCategoryColor: (_) => Colors.deepOrange,
                  ),
                  child: const Text('Open Config'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Config'));
      await tester.pumpAndSettle();

      // Verify options derived and displayed
      expect(find.text('Steam'), findsOneWidget);
      expect(find.text('Fried'), findsOneWidget);
      expect(find.text('Pan Fried'), findsOneWidget);

      // Enter cost 10 for Fried (index 1), and 20 for Pan Fried (index 2)
      final costFields = find.byType(TextField);
      await tester.enterText(costFields.at(1), '10');
      await tester.enterText(costFields.at(2), '20');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(controller.getCategoryCost('Fried'), 10.0);
      expect(controller.getCategoryCost('Pan Fried'), 20.0);
    });

    testWidgets('ManageCategoriesDialog lists categories and allows searching and editing',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(id: '1', name: 'Chai', price: 20, category: 'Beverages'),
        const MenuItem(id: '2', name: 'Samosa', price: 25, category: 'Snacks'),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Cup Fee',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ManageCategoriesDialog.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                  ),
                  child: const Text('Manage Categories'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Manage Categories'));
      await tester.pumpAndSettle();

      expect(find.text('Category Surcharges & Options'), findsOneWidget);
      expect(find.text('Beverages'), findsOneWidget);
      expect(find.text('+₹5 Cup Fee'), findsOneWidget);
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('No extra surcharge'), findsOneWidget);

      // Search filter
      await tester.enterText(find.widgetWithText(TextField, 'Filter categories...'), 'Snack');
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsOneWidget);
      expect(find.text('Beverages'), findsNothing);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Category Surcharges & Options'), findsNothing);
    });

    testWidgets('CartBottomSheet displays category fee in split and summary footer',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(id: '1', name: 'Chai', price: 20, category: 'Beverages'),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();
      await controller.updateCategoryCost(
        categoryName: 'Beverages',
        additionalCost: 5.0,
        reason: 'Cup Fee',
      );

      controller.addToCart(controller.findItem('1'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CartBottomSheet.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.blue,
                    onCheckout: () {},
                    onClearCart: () {},
                  ),
                  child: const Text('Open Cart'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      // Verify item split display
      expect(find.text('Split: Item ₹20 + Cup Fee ₹5'), findsOneWidget);

      // Verify cart summary footer breakdown
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('₹20'), findsWidgets);
      expect(find.text('Category Additional Costs'), findsOneWidget);
      expect(find.text('+₹5'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);
      expect(find.text('₹25'), findsWidgets);
    });

    test('MenuItem displayName returns customDisplayName or falls back to name', () {
      final momos = const MenuItem(
        id: '1',
        name: 'Veg Steamed Momos',
        price: 80,
        category: 'Momos',
        displayName: 'Momos',
      );
      expect(momos.displayName, 'Momos (Momos)');
      expect(momos.customDisplayName, 'Momos');

      final noCustom = const MenuItem(
        id: '2',
        name: 'Veg Steamed Momos',
        price: 80,
        category: 'Momos',
      );
      expect(noCustom.displayName, 'Veg Steamed Momos (Momos)');
      expect(noCustom.customDisplayName, isNull);

      final blank = const MenuItem(
        id: '3',
        name: 'Veg Steamed Momos',
        price: 80,
        category: 'Momos',
        displayName: '   ',
      );
      expect(blank.displayName, 'Veg Steamed Momos (Momos)');

      final copied = momos.copyWith(price: 90);
      expect(copied.displayName, 'Momos (Momos)');
      expect(copied.customDisplayName, 'Momos');

      final cleared = momos.copyWith(clearDisplayName: true);
      expect(cleared.customDisplayName, isNull);
      expect(cleared.displayName, 'Veg Steamed Momos (Momos)');

      final json = momos.toJson();
      expect(json['displayName'], 'Momos');
      final fromJson = MenuItem.fromJson(json);
      expect(fromJson.customDisplayName, 'Momos');
      expect(fromJson.displayName, 'Momos (Momos)');
    });

    test('AggregatedOrderItem displayName uses itemDisplayName or falls back to itemName', () {
      final aggItem = const AggregatedOrderItem(
        itemId: '1',
        itemName: 'Veg Steamed Momos',
        category: 'Momos',
        totalQuantity: 2,
        tickets: [OrderTicketQuantity(token: 101, quantity: 2)],
        itemDisplayName: 'Momos',
      );
      expect(aggItem.displayName, 'Momos (Momos)');

      final aggNoAlias = const AggregatedOrderItem(
        itemId: '2',
        itemName: 'Veg Steamed Momos',
        category: 'Momos',
        totalQuantity: 2,
        tickets: [OrderTicketQuantity(token: 101, quantity: 2)],
      );
      expect(aggNoAlias.displayName, 'Veg Steamed Momos (Momos)');
    });

    test('OrderController respects MenuItem custom display name in menu, filteredMenu, and findItem', () async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_momos',
          name: 'Veg Steamed Momos',
          price: 80,
          category: 'Momos',
          displayName: 'Momos',
        ),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();

      expect(controller.menu.first.displayName, 'Momos (Momos)');
      expect(controller.filteredMenu.first.displayName, 'Momos (Momos)');
      expect(controller.findItem('item_momos').displayName, 'Momos (Momos)');

      // Add to cart and verify cart findItem
      controller.addToCart(controller.findItem('item_momos'));
      final orderItem = controller.findItem('item_momos');
      expect(orderItem.displayName, 'Momos (Momos)');
    });

    testWidgets('MenuItemCard and CartBottomSheet render MenuItem custom displayName',
        (tester) async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_momos',
          name: 'Veg Steamed Momos',
          displayName: 'Momos',
          price: 80,
          category: 'Momos',
        ),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();

      // 1. Render MenuItemCard
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MenuItemCard(
                item: controller.menu.first,
                cart: const {},
                getCategoryColor: (_) => Colors.deepOrange,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );

      // Verify card displays 'Momos (Momos)'
      expect(find.text('Momos (Momos)'), findsOneWidget);

      // 2. Add to cart and verify in CartBottomSheet
      controller.addToCart(controller.findItem('item_momos'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CartBottomSheet.show(
                    context,
                    controller: controller,
                    getCategoryColor: (_) => Colors.deepOrange,
                    onCheckout: () {},
                    onClearCart: () {},
                  ),
                  child: const Text('Open Cart'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Cart'));
      await tester.pumpAndSettle();

      // Verify item title in cart displays 'Momos (Momos)'
      expect(find.text('Momos (Momos)'), findsOneWidget);
    });

    test('OrderController normalizeCategoryKey handles uneven whitespace around slashes', () {
      expect(
        OrderController.normalizeCategoryKey('Momos /  Fried Momos /   Pan Fried Momos'),
        'momos / fried momos / pan fried momos',
      );
      expect(
        OrderController.normalizeCategoryKey('  Beverages  '),
        'beverages',
      );
    });

    testWidgets('CategoryAccordionCard renders multi-option cost badge inside column without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryAccordionCard(
              catName: 'Fried Momos / Pan Fried Momos / Kurkure Momos / Peri-Peri Momos',
              items: const [
                MenuItem(id: '1', name: 'Veg Momos', price: 150, category: 'Momos'),
              ],
              isExpanded: true,
              costDescription: 'Fried Momos (+₹10), Pan Fried Momos (+₹20), Kurkure Momos (+₹30), Peri-Peri Momos (+₹40)',
              getCategoryColor: (_) => Colors.deepOrange,
              onToggle: () {},
              itemCardBuilder: (item) => Text(item.name),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no flutter overflow exceptions were thrown
      expect(tester.takeException(), isNull);

      // Verify title is rendered
      expect(find.text('Fried Momos / Pan Fried Momos / Kurkure Momos / Peri-Peri Momos'), findsOneWidget);

      // Verify the long multi-option badge is present
      expect(find.text('Fried Momos (+₹10), Pan Fried Momos (+₹20), Kurkure Momos (+₹30), Peri-Peri Momos (+₹40)'), findsOneWidget);
    });

    test('Selected category is preserved in brackets in cart, active orders, and item summary', () async {
      final storage = InMemoryStallStorage(initialMenu: [
        const MenuItem(
          id: 'item_chicken',
          name: 'Chicken Momos',
          displayName: 'Chicken',
          price: 180,
          category: 'Fried Momos / Pan Fried Momos / Kurkure Momos / Peri-Peri Momos',
        ),
        const MenuItem(
          id: 'item_gobi',
          name: 'Gobi Manchuria Gravy',
          displayName: 'Gobi Manchuria',
          price: 170,
          category: 'Starters',
        ),
      ]);
      final controller = OrderController(storageService: storage);
      await controller.loadPersistedData();

      // 1. Regular item without slash in category preserves category in brackets
      final gobiItem = controller.findItem('item_gobi');
      expect(gobiItem.displayName, 'Gobi Manchuria (Starters)');

      // 2. Add customized item with selected category variant (Kurkure Momos)
      final chickenBase = controller.findItem('item_chicken');
      controller.addCustomizedItemToCart(
        baseItem: chickenBase,
        resolvedCategory: 'Kurkure Momos',
      );

      // Cart item key: item_chicken_cat_Kurkure Momos
      final cartItemKey = controller.cart.keys.first;
      final resolvedCartItem = controller.findItem(cartItemKey);
      expect(resolvedCartItem.displayName, 'Chicken (Kurkure Momos)');

      // 3. Punch order and verify Active Orders item list has category in brackets
      final orderResult = await controller.punchOrUpdateOrder(customerName: null);
      final order = controller.orders.firstWhere((o) => o.token == orderResult.token);
      final activeItems = controller.getOrderItemsWithCategory(order);
      expect(activeItems.length, 1);
      expect(activeItems.first.displayName, 'Chicken (Kurkure Momos)');

      // 4. Confirm payment so order is in Item Summary
      await controller.confirmPayment(token: order.token, paymentMethod: 'Cash');
      final aggregated = controller.combinedActiveOrders;
      expect(aggregated.length, 1);
      expect(aggregated.first.displayName, 'Chicken (Kurkure Momos)');
    });
  });
}


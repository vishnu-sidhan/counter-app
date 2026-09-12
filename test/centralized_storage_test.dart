import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/counter_app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.reset();
  });

  tearDown(() {
    AppStorage.reset();
  });

  test('AppStorage defaults to local SharedPreferences services', () {
    expect(AppStorage.instance.stallStorage, isA<StallStorageService>());
    expect(AppStorage.instance.counterStorage, isA<CounterStorageService>());
  });

  test('AppStorage.configure swaps StallStorage and CounterStorage seamlessly', () async {
    final now = DateTime.now();
    final customStallStorage = InMemoryStallStorage(
      initialMenu: [
        const MenuItem(id: 'm1', name: 'Cloud Burger', price: 99.0, category: 'Food'),
      ],
      initialToken: 42,
    );
    final customCounterStorage = InMemoryCounterStorage(
      initialCounters: [
        CounterModel(
          id: 'c1',
          title: 'Coffee Cups',
          count: 5,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    AppStorage.configure(
      stallStorage: customStallStorage,
      counterStorage: customCounterStorage,
    );

    expect(AppStorage.instance.stallStorage, equals(customStallStorage));
    expect(AppStorage.instance.counterStorage, equals(customCounterStorage));

    // Verify OrderController picks up configured custom storage by default
    final orderController = OrderController();
    await orderController.loadPersistedData();

    expect(orderController.menu.length, 1);
    expect(orderController.menu.first.name, 'Cloud Burger');
    expect(orderController.nextToken, 42);

    // Verify CounterController picks up configured custom storage by default
    final counterController = CounterController();
    await counterController.init();

    expect(counterController.counters.length, 1);
    expect(counterController.counters.first.title, 'Coffee Cups');
  });

  test('InMemoryStallStorage handles full CRUD lifecycle', () async {
    final storage = InMemoryStallStorage();

    expect(await storage.loadMenu(), isEmpty);
    expect(await storage.loadOrders(), isEmpty);
    expect(await storage.loadNextToken(), 1);

    await storage.saveMenu([
      const MenuItem(id: '1', name: 'Dosa', price: 50.0, category: 'Tiffin'),
    ]);
    expect((await storage.loadMenu()).length, 1);

    await storage.saveNextToken(10);
    expect(await storage.loadNextToken(), 10);

    final order1 = StallOrder(
      token: 10,
      itemsSummary: '2x Dosa',
      timestamp: DateTime.now(),
      items: {'1': 2},
      total: 100.0,
      isCompleted: false,
    );
    final order2 = StallOrder(
      token: 11,
      itemsSummary: '1x Dosa',
      timestamp: DateTime.now(),
      items: {'1': 1},
      total: 50.0,
      isCompleted: true,
      completedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    await storage.saveOrders([order1, order2]);
    expect((await storage.loadOrders()).length, 2);

    // Archive completed order
    final archivedCount = await storage.archiveCompletedOrders(
      threshold: const Duration(hours: 1),
    );
    expect(archivedCount, 1);
    expect((await storage.loadOrders()).length, 1);
    expect((await storage.loadArchivedOrders()).length, 1);

    // Clear all
    await storage.clearAllOrders(resetToken: true);
    expect(await storage.loadOrders(), isEmpty);
    expect(await storage.loadArchivedOrders(), isEmpty);
    expect(await storage.loadNextToken(), 1);
  });

  test('Custom cloud storage implementing StallStorage integrates seamlessly with AppStorage', () async {
    final cloudStorage = _MockCloudStallStorage();
    AppStorage.configure(stallStorage: cloudStorage);

    final controller = OrderController();
    await controller.loadPersistedData();

    expect(controller.menu.length, 1);
    expect(controller.menu.first.name, 'Cloud Pizza');
    expect(controller.nextToken, 99);

    await controller.storageService.saveNextToken(100);
    expect(cloudStorage.nextTokenValue, 100);
  });

  test('AppStorage.reset restores default SharedPreferences instances', () {
    AppStorage.configure(stallStorage: InMemoryStallStorage());
    expect(AppStorage.instance.stallStorage, isA<InMemoryStallStorage>());

    AppStorage.reset();
    expect(AppStorage.instance.stallStorage, isA<StallStorageService>());
    expect(AppStorage.instance.counterStorage, isA<CounterStorageService>());
  });
}

class _MockCloudStallStorage implements StallStorage {
  int nextTokenValue = 99;
  List<MenuItem> menu = [
    const MenuItem(id: 'api_1', name: 'Cloud Pizza', price: 250.0, category: 'Pizza'),
  ];
  List<StallOrder> orders = [];
  final List<StallOrder> archives = [];

  @override
  Future<List<MenuItem>> loadMenu() async => menu;

  @override
  Future<void> saveMenu(List<MenuItem> items) async => menu = items;

  @override
  Future<List<StallOrder>> loadOrders() async => orders;

  @override
  Future<void> saveOrders(List<StallOrder> o) async => orders = o;

  @override
  Future<int> loadNextToken() async => nextTokenValue;

  @override
  Future<void> saveNextToken(int token) async => nextTokenValue = token;

  @override
  Future<List<StallOrder>> clearCompletedOrders() async => orders;

  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async => 0;

  @override
  Future<List<StallOrder>> loadArchivedOrders() async => archives;

  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {}

  List<ItemCategory> categories = [];

  @override
  Future<List<ItemCategory>> loadCategories() async => categories;

  @override
  Future<void> saveCategories(List<ItemCategory> cats) async => categories = cats;
}

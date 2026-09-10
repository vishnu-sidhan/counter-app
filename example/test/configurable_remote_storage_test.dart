import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/counter_app.dart';
import 'package:counter_app_example/configurable_remote_storage.dart';
import 'package:counter_app_example/remote_storage_config_dialog.dart';
import 'package:counter_app_example/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteStorageConfig', () {
    test('defaults and serialization to SharedPreferences', () async {
      final initial = await RemoteStorageConfig.load();
      expect(initial.isRemoteEnabled, isFalse);
      expect(initial.baseUrl, isEmpty);
      expect(initial.authToken, isEmpty);
      expect(initial.stallId, isEmpty);
      expect(initial.enableOfflineCache, isTrue);

      const updated = RemoteStorageConfig(
        isRemoteEnabled: true,
        baseUrl: 'https://api.mypos.com/v1',
        authToken: 'secret-token-123',
        stallId: 'stall_01',
        enableOfflineCache: true,
      );
      await updated.save();

      final reloaded = await RemoteStorageConfig.load();
      expect(reloaded.isRemoteEnabled, isTrue);
      expect(reloaded.baseUrl, 'https://api.mypos.com/v1');
      expect(reloaded.authToken, 'secret-token-123');
      expect(reloaded.stallId, 'stall_01');
      expect(reloaded.enableOfflineCache, isTrue);

      await RemoteStorageConfig.resetToLocal();
      final afterReset = await RemoteStorageConfig.load();
      expect(afterReset.isRemoteEnabled, isFalse);
    });
  });

  group('ConfigurableRemoteStorage', () {
    test('testConnection returns success on 200 OK', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/menu')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not Found', 404);
      });

      final storage = ConfigurableRemoteStorage(
        baseUrl: 'https://api.mypos.com/v1',
        authToken: 'my-bearer-token',
        stallId: 'main_stall',
        client: mockClient,
      );

      final result = await storage.testConnection();
      expect(result.success, isTrue);
      expect(result.message, contains('HTTP 200'));
    });

    test('testConnection returns failure on 401 Unauthorized', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized', 401);
      });

      final storage = ConfigurableRemoteStorage(
        baseUrl: 'https://api.mypos.com/v1',
        authToken: 'bad-token',
        client: mockClient,
      );

      final result = await storage.testConnection();
      expect(result.success, isFalse);
      expect(result.message, contains('HTTP 401'));
    });

    test('loadMenu parses server items successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.headers['X-Stall-Id'], 'stall_42');

        final sampleMenu = [
          {'id': 'item_1', 'name': 'Butter Dosa', 'price': 80.0, 'category': 'Tiffin'},
          {'id': 'item_2', 'name': 'Filter Coffee', 'price': 25.0, 'category': 'Beverages'},
        ];
        return http.Response(jsonEncode(sampleMenu), 200);
      });

      final storage = ConfigurableRemoteStorage(
        baseUrl: 'https://api.mypos.com/v1',
        authToken: 'test-token',
        stallId: 'stall_42',
        client: mockClient,
      );

      final menu = await storage.loadMenu();
      expect(menu.length, 2);
      expect(menu[0].name, 'Butter Dosa');
      expect(menu[0].price, 80.0);
      expect(menu[1].name, 'Filter Coffee');
    });

    test('loadMenu falls back to offline cache when network fails', () async {
      final fallback = InMemoryStallStorage(
        initialMenu: [
          const MenuItem(id: 'offline_1', name: 'Cached Samosa', price: 20.0, category: 'Snacks'),
        ],
      );

      final failingClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final storage = ConfigurableRemoteStorage(
        baseUrl: 'https://api.unreachable-server.com',
        fallbackStorage: fallback,
        enableOfflineCache: true,
        client: failingClient,
      );

      final menu = await storage.loadMenu();
      expect(menu.length, 1);
      expect(menu.first.name, 'Cached Samosa');
    });

    test('loadOrders and saveOrders integrate with server', () async {
      final serverOrders = <Map<String, dynamic>>[];

      final mockClient = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/orders')) {
          return http.Response(jsonEncode(serverOrders), 200);
        }
        if ((request.method == 'POST' || request.method == 'PUT') &&
            request.url.path.endsWith('/orders')) {
          final decoded = jsonDecode(request.body) as List;
          serverOrders.clear();
          serverOrders.addAll(decoded.cast<Map<String, dynamic>>());
          return http.Response(jsonEncode({'saved': true}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final storage = ConfigurableRemoteStorage(
        baseUrl: 'https://api.mypos.com/v1',
        client: mockClient,
      );

      final initialOrders = await storage.loadOrders();
      expect(initialOrders, isEmpty);

      final newOrder = StallOrder(
        token: 101,
        itemsSummary: '1x Filter Coffee',
        timestamp: DateTime.now(),
        items: {'item_2': 1},
        total: 25.0,
      );
      await storage.saveOrders([newOrder]);

      final loaded = await storage.loadOrders();
      expect(loaded.length, 1);
      expect(loaded.first.token, 101);
      expect(loaded.first.total, 25.0);
    });

    testWidgets('Opening storage dialog from ExampleHostApp finds MaterialLocalizations and renders dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ExampleHostApp(
          initialConfig: RemoteStorageConfig(),
        ),
      );
      await tester.pumpAndSettle();

      // Find the storage configuration icon button or pill
      final storageButton = find.byTooltip('Storage Configuration');
      expect(storageButton, findsOneWidget);

      // Tap to open the dialog
      await tester.tap(storageButton);
      await tester.pumpAndSettle();

      // Verify the dialog opened cleanly without any MaterialLocalizations error
      expect(find.byType(RemoteStorageConfigDialog), findsOneWidget);
      expect(find.text('Storage Configuration'), findsOneWidget);

      // Switch to Remote Cloud API segment
      final remoteTab = find.text('Remote Cloud API');
      expect(remoteTab, findsOneWidget);
      await tester.tap(remoteTab);
      await tester.pumpAndSettle();

      // Remote fields now visible
      expect(find.text('Server Base URL *'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);

      // Dismiss dialog
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.byType(RemoteStorageConfigDialog), findsNothing);
    });
  });
}

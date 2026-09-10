import 'stall_storage.dart';
import 'counter_storage.dart';
import '../services/stall_storage_service.dart';
import '../services/counter_storage_service.dart';

/// Centralized storage coordinator for the entire module/application.
///
/// Enables dependency injection and swapping between local (SharedPreferences)
/// and remote storage (REST / Firebase / Supabase) globally with a single line of code.
///
/// Example usage in a host app:
/// ```dart
/// // Swap to custom/remote storage globally
/// AppStorage.configure(
///   stallStorage: MyRemoteStallStorage(), // any class implementing StallStorage
/// );
/// ```
class AppStorage {
  static AppStorage _instance = AppStorage();

  /// The active centralized instance of [AppStorage].
  static AppStorage get instance => _instance;

  final StallStorage stallStorage;
  final CounterStorage counterStorage;

  AppStorage({
    StallStorage? stallStorage,
    CounterStorage? counterStorage,
  })  : stallStorage = stallStorage ?? StallStorageService(),
        counterStorage = counterStorage ?? CounterStorageService();

  /// Globally configures the centralized storage provider.
  /// Pass custom implementations of [StallStorage] or [CounterStorage] to
  /// switch to remote backends, databases, or mock storage.
  static void configure({
    StallStorage? stallStorage,
    CounterStorage? counterStorage,
  }) {
    _instance = AppStorage(
      stallStorage: stallStorage ?? _instance.stallStorage,
      counterStorage: counterStorage ?? _instance.counterStorage,
    );
  }

  /// Resets back to default local storage providers. Useful in unit tests.
  static void reset() {
    _instance = AppStorage();
  }
}

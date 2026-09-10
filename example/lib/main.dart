import 'package:flutter/material.dart';
import 'package:counter_app/counter_app.dart';
import 'configurable_remote_storage.dart';
import 'remote_storage_config_dialog.dart';

/// Example host application demonstrating how an external app consumes
/// the `counter_app` / `stall_pos` package as a modular dependency,
/// and how easily storage can be centralized and swapped between local and remote
/// via code or interactively through the UI.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved remote storage configuration from SharedPreferences
  final storageConfig = await RemoteStorageConfig.load();

  // Apply remote storage configuration if previously configured and enabled
  if (storageConfig.isRemoteEnabled && storageConfig.baseUrl.trim().isNotEmpty) {
    AppStorage.configure(
      stallStorage: ConfigurableRemoteStorage(
        baseUrl: storageConfig.baseUrl,
        authToken: storageConfig.authToken.isNotEmpty
            ? storageConfig.authToken
            : null,
        stallId:
            storageConfig.stallId.isNotEmpty ? storageConfig.stallId : null,
        enableOfflineCache: storageConfig.enableOfflineCache,
      ),
      counterStorage: InMemoryCounterStorage(),
    );
  } else {
    AppStorage.reset();
  }

  await ThemeController.instance.init();

  runApp(ExampleHostApp(initialConfig: storageConfig));
}

/// Root application widget that sets up MaterialApp and theme bindings.
class ExampleHostApp extends StatelessWidget {
  final RemoteStorageConfig initialConfig;

  const ExampleHostApp({
    super.key,
    required this.initialConfig,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Stall POS Host App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: ExampleHomeScreen(initialConfig: initialConfig),
        );
      },
    );
  }
}

/// Home screen widget placed inside MaterialApp so it has access to
/// Navigator, ScaffoldMessenger, and MaterialLocalizations.
class ExampleHomeScreen extends StatefulWidget {
  final RemoteStorageConfig initialConfig;

  const ExampleHomeScreen({
    super.key,
    required this.initialConfig,
  });

  @override
  State<ExampleHomeScreen> createState() => _ExampleHomeScreenState();
}

class _ExampleHomeScreenState extends State<ExampleHomeScreen> {
  late RemoteStorageConfig _config;
  late CounterController _counterController;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _initController();
  }

  void _initController() {
    _counterController = CounterController();
    _counterController.init();
  }

  Future<void> _openStorageConfigDialog() async {
    // context here is safely below MaterialApp, guaranteeing MaterialLocalizations and Navigator exist
    final newConfig = await RemoteStorageConfigDialog.show(context, _config);
    if (newConfig == null) return;

    await newConfig.save();

    setState(() {
      _config = newConfig;

      if (newConfig.isRemoteEnabled && newConfig.baseUrl.trim().isNotEmpty) {
        AppStorage.configure(
          stallStorage: ConfigurableRemoteStorage(
            baseUrl: newConfig.baseUrl,
            authToken: newConfig.authToken.isNotEmpty
                ? newConfig.authToken
                : null,
            stallId: newConfig.stallId.isNotEmpty ? newConfig.stallId : null,
            enableOfflineCache: newConfig.enableOfflineCache,
          ),
          counterStorage: InMemoryCounterStorage(),
        );
      } else {
        AppStorage.reset();
      }

      _initController();
    });

    if (!mounted) return;

    final isRemote = _config.isRemoteEnabled && _config.baseUrl.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isRemote ? Icons.cloud_done : Icons.storage_rounded,
              color: isRemote ? Colors.greenAccent : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isRemote
                    ? 'Connected to Remote API: ${_config.baseUrl}'
                    : 'Swapped to Local Device Storage (SharedPreferences)',
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatServerLabel(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : url;
      return host.length > 20 ? '${host.substring(0, 18)}...' : host;
    } catch (_) {
      return url.length > 20 ? '${url.substring(0, 18)}...' : url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = _config.isRemoteEnabled && _config.baseUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host App - Stall POS'),
        actions: [
          // Interactive Storage Badge Pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: InkWell(
              onTap: _openStorageConfigDialog,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isRemote
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isRemote ? Colors.green : Colors.grey.shade400,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRemote ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRemote
                          ? 'Remote: ${_formatServerLabel(_config.baseUrl)}'
                          : 'Local Storage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isRemote
                            ? (ThemeController.instance.isDark
                                ? Colors.greenAccent
                                : Colors.green.shade800)
                            : (ThemeController.instance.isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Storage Configuration',
            icon: Icon(
              isRemote ? Icons.cloud_sync : Icons.cloud_off_outlined,
              color: isRemote ? Colors.green : null,
            ),
            onPressed: _openStorageConfigDialog,
          ),
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              ThemeController.instance.isDark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => ThemeController.instance.toggleTheme(),
          ),
        ],
      ),
      body: MainNavigationScreen(
        controller: _counterController,
        initialIndex: 1, // Start directly in Stall POS
      ),
    );
  }
}

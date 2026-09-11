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

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      controller: _counterController,
      initialIndex: 1, // Start directly in Stall POS
      extraActions: [
        StorageConnectionButton(
          config: _config,
          onTap: _openStorageConfigDialog,
        ),
      ],
    );
  }
}

/// A responsive, interactive button displaying current storage connection state
/// (Local Storage vs Remote API) and providing one-tap access to storage configuration.
class StorageConnectionButton extends StatelessWidget {
  final RemoteStorageConfig config;
  final VoidCallback onTap;

  const StorageConnectionButton({
    super.key,
    required this.config,
    required this.onTap,
  });

  String _formatServerLabel(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : url;
      return host.length > 18 ? '${host.substring(0, 16)}...' : host;
    } catch (_) {
      return url.length > 18 ? '${url.substring(0, 16)}...' : url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = config.isRemoteEnabled && config.baseUrl.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    const tooltipText = 'Storage Configuration';

    if (isCompact) {
      return Tooltip(
        message: tooltipText,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isRemote
                        ? (isDark
                            ? Colors.green.withValues(alpha: 0.25)
                            : Colors.green.withValues(alpha: 0.12))
                        : (isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRemote ? Colors.green : Colors.grey.shade400,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isRemote ? Icons.cloud_done : Icons.cloud_outlined,
                    size: 18,
                    color: isRemote
                        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRemote ? Colors.greenAccent : Colors.grey,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltipText,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: isRemote
                  ? (isDark
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.12))
                  : (isDark
                      ? Colors.white10
                      : Colors.grey.withValues(alpha: 0.12)),
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
                Icon(
                  isRemote ? Icons.cloud_done : Icons.cloud_outlined,
                  size: 15,
                  color: isRemote
                      ? (isDark ? Colors.greenAccent : Colors.green.shade800)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
                const SizedBox(width: 5),
                Text(
                  isRemote
                      ? 'Remote: ${_formatServerLabel(config.baseUrl)}'
                      : 'Local Storage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isRemote
                        ? (isDark
                            ? Colors.greenAccent
                            : Colors.green.shade800)
                        : (isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.tune_rounded,
                  size: 13,
                  color: isRemote
                      ? (isDark
                          ? Colors.greenAccent.withValues(alpha: 0.8)
                          : Colors.green.shade700)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

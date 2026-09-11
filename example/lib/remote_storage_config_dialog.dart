import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'configurable_remote_storage.dart';

/// Data class holding remote storage settings for the example host application.
class RemoteStorageConfig {
  final bool isRemoteEnabled;
  final String baseUrl;
  final String authToken;
  final String stallId;
  final bool enableOfflineCache;

  const RemoteStorageConfig({
    this.isRemoteEnabled = false,
    this.baseUrl = '',
    this.authToken = '',
    this.stallId = '',
    this.enableOfflineCache = true,
  });

  static const String _keyEnabled = 'example_remote_is_enabled_v1';
  static const String _keyBaseUrl = 'example_remote_base_url_v1';
  static const String _keyAuthToken = 'example_remote_auth_token_v1';
  static const String _keyStallId = 'example_remote_stall_id_v1';
  static const String _keyOfflineCache = 'example_remote_offline_cache_v1';

  static Future<RemoteStorageConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RemoteStorageConfig(
      isRemoteEnabled: prefs.getBool(_keyEnabled) ?? false,
      baseUrl: prefs.getString(_keyBaseUrl) ?? '',
      authToken: prefs.getString(_keyAuthToken) ?? '',
      stallId: prefs.getString(_keyStallId) ?? '',
      enableOfflineCache: prefs.getBool(_keyOfflineCache) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, isRemoteEnabled);
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyAuthToken, authToken);
    await prefs.setString(_keyStallId, stallId);
    await prefs.setBool(_keyOfflineCache, enableOfflineCache);
  }

  static Future<void> resetToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
  }
}

/// Interactive dialog for managing and configuring remote cloud storage from the UI.
class RemoteStorageConfigDialog extends StatefulWidget {
  final RemoteStorageConfig currentConfig;

  const RemoteStorageConfigDialog({
    super.key,
    required this.currentConfig,
  });

  static Future<RemoteStorageConfig?> show(
    BuildContext context,
    RemoteStorageConfig currentConfig,
  ) {
    return showDialog<RemoteStorageConfig>(
      context: context,
      builder: (ctx) => RemoteStorageConfigDialog(currentConfig: currentConfig),
    );
  }

  @override
  State<RemoteStorageConfigDialog> createState() =>
      _RemoteStorageConfigDialogState();
}

class _RemoteStorageConfigDialogState extends State<RemoteStorageConfigDialog> {
  late bool _isRemote;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _stallIdController;
  late bool _enableOfflineCache;

  bool _obscureToken = true;
  bool _isTesting = false;
  String? _testResultStatus;
  bool? _testResultSuccess;

  @override
  void initState() {
    super.initState();
    _isRemote = widget.currentConfig.isRemoteEnabled;
    _urlController = TextEditingController(text: widget.currentConfig.baseUrl);
    _tokenController = TextEditingController(text: widget.currentConfig.authToken);
    _stallIdController = TextEditingController(text: widget.currentConfig.stallId);
    _enableOfflineCache = widget.currentConfig.enableOfflineCache;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _stallIdController.dispose();
    super.dispose();
  }

  Future<void> _runConnectionTest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !Uri.tryParse(url)!.hasScheme) {
      setState(() {
        _testResultSuccess = false;
        _testResultStatus = 'Please enter a valid URL (e.g. https://api.my-stall.com)';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResultStatus = null;
    });

    final tempStorage = ConfigurableRemoteStorage(
      baseUrl: url,
      authToken: _tokenController.text.trim(),
      stallId: _stallIdController.text.trim(),
    );

    final result = await tempStorage.testConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResultSuccess = result.success;
        _testResultStatus = result.message;
      });
    }
  }

  void _prefillDemo() {
    setState(() {
      _isRemote = true;
      _urlController.text = 'https://mock.stallpos.dev/api/v1';
      _tokenController.text = 'demo-stall-token-123';
      _stallIdController.text = 'stall_main';
      _enableOfflineCache = true;
      _testResultStatus = null;
    });
  }

  Future<void> _handleSave() async {
    if (_isRemote && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a valid Remote Base URL')),
      );
      return;
    }

    final newConfig = RemoteStorageConfig(
      isRemoteEnabled: _isRemote,
      baseUrl: _urlController.text.trim(),
      authToken: _tokenController.text.trim(),
      stallId: _stallIdController.text.trim(),
      enableOfflineCache: _enableOfflineCache,
    );

    await newConfig.save();
    if (mounted) {
      Navigator.of(context).pop(newConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cloud_sync_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Configuration',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Switch between Local & Remote Cloud Storage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Storage Mode Selector
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Local Storage'),
                    icon: Icon(Icons.phone_android_rounded),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Remote Cloud API'),
                    icon: Icon(Icons.cloud_outlined),
                  ),
                ],
                selected: {_isRemote},
                onSelectionChanged: (set) {
                  setState(() {
                    _isRemote = set.first;
                    _testResultStatus = null;
                  });
                },
              ),
              const SizedBox(height: 20),

              if (!_isRemote) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Using local device persistence (SharedPreferences). Data is stored directly in your browser or device storage.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Quick Demo pre-fill button
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'API Connection Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _prefillDemo,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Fill Demo Server'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Base URL
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Server Base URL *',
                    hintText: 'https://api.my-stall.com/v1',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Auth Token / API Key
                TextField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    labelText: 'API Key / Bearer Token (Optional)',
                    hintText: 'eyJh...',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() => _obscureToken = !_obscureToken);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stall ID
                TextField(
                  controller: _stallIdController,
                  decoration: InputDecoration(
                    labelText: 'Stall / Tenant ID (Optional)',
                    hintText: 'e.g. stall_01',
                    prefixIcon: const Icon(Icons.storefront_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Offline Cache Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offline-First Caching'),
                  subtitle: const Text(
                    'Cache data locally so the app still operates seamlessly if internet connection drops.',
                  ),
                  value: _enableOfflineCache,
                  onChanged: (val) => setState(() => _enableOfflineCache = val),
                  activeThumbColor: Colors.blueAccent,
                ),
                const SizedBox(height: 12),

                // Test Connection Button & Status
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _runConnectionTest,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find_rounded),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                  ),
                ),

                if (_testResultStatus != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (_testResultSuccess ?? false)
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_testResultSuccess ?? false)
                            ? Colors.green
                            : Colors.redAccent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_testResultSuccess ?? false)
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: (_testResultSuccess ?? false)
                              ? Colors.green
                              : Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testResultStatus!,
                            style: TextStyle(
                              fontSize: 13,
                              color: (_testResultSuccess ?? false)
                                  ? Colors.green[800]
                                  : Colors.redAccent[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _handleSave,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Apply & Connect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

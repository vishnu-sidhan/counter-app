import 'package:flutter/material.dart';
import 'controllers/counter_controller.dart';
import 'controllers/theme_controller.dart';
import 'data/storage/app_storage.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = CounterController(
    storageService: AppStorage.instance.counterStorage,
  );
  await controller.init();
  await ThemeController.instance.init();

  runApp(StallPosApp(controller: controller));
}

/// Main application widget for StallPOS.
class StallPosApp extends StatelessWidget {
  final CounterController controller;
  final ThemeController? themeController;
  final int initialIndex;

  const StallPosApp({
    super.key,
    required this.controller,
    this.themeController,
    this.initialIndex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final themeCtrl = themeController ?? ThemeController.instance;

    return ListenableBuilder(
      listenable: themeCtrl,
      builder: (context, _) {
        return MaterialApp(
          title: 'StallPOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeCtrl.themeMode,
          home: MainNavigationScreen(
            controller: controller,
            initialIndex: initialIndex,
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'controllers/counter_controller.dart';
import 'controllers/theme_controller.dart';
import 'data/services/counter_storage_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = CounterStorageService();
  final controller = CounterController(storageService: storageService);
  await controller.init();
  await ThemeController.instance.init();

  runApp(MultiCounterApp(controller: controller));
}

class MultiCounterApp extends StatelessWidget {
  final CounterController controller;
  final ThemeController? themeController;
  final int initialIndex;

  const MultiCounterApp({
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

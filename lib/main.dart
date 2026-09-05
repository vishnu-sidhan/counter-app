import 'package:flutter/material.dart';
import 'controllers/counter_controller.dart';
import 'data/services/counter_storage_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = CounterStorageService();
  final controller = CounterController(storageService: storageService);
  await controller.init();

  runApp(MultiCounterApp(controller: controller));
}

class MultiCounterApp extends StatelessWidget {
  final CounterController controller;

  const MultiCounterApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi Counter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: MainNavigationScreen(controller: controller),
    );
  }
}

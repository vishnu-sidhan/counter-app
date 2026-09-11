import 'package:flutter/material.dart';
import '../controllers/counter_controller.dart';
import 'home_screen.dart';
import 'stall_pos_screen.dart';

/// Main root screen providing bottom navigation between Multi-Counter and Stall POS.
class MainNavigationScreen extends StatefulWidget {
  final CounterController controller;
  final int initialIndex;
  final List<Widget>? extraActions;

  const MainNavigationScreen({
    super.key,
    required this.controller,
    this.initialIndex = 1,
    this.extraActions,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            controller: widget.controller,
            extraActions: widget.extraActions,
          ),
          StallPosScreen(
            extraActions: widget.extraActions,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Counters',
            tooltip: 'Counters',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Stall POS',
            tooltip: 'Stall POS',
          ),
        ],
      ),
    );
  }
}

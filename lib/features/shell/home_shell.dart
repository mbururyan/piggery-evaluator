import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/widgets/empty_tab.dart';
import '../home/home_tab.dart';

/// The frame every signed-in screen lives in: app bar, the 4-tab bottom
/// nav, and (from 2c) the drawer and (from 2d) the sync icon.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Home shows the app name; the other tabs say what they hold.
  static const _titles = [
    AppInfo.name,
    'My farmers',
    'My visits',
    'Analytics',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),

      // IndexedStack keeps all four tabs alive instead of rebuilding them on
      // every switch. Later, that means the Farmers list keeps its scroll
      // position and search text when an EO hops to Home and back.
      body: IndexedStack(
        index: _index,
        children: const [
          HomeTab(),
          EmptyTab(
            icon: Icons.groups_outlined,
            message: 'Your assigned farmers will appear here.',
            searchHint: 'Search by name, PF or phone',
          ),
          EmptyTab(
            icon: Icons.assignment_outlined,
            message: 'Visits you submit will appear here.',
          ),
          EmptyTab(
            icon: Icons.bar_chart,
            message: 'Your visit numbers will appear here.',
          ),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Farmers',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Visits',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
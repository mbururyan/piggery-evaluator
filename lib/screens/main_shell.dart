import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/farmers_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/visits_tab.dart';

/// The signed-in shell: four peer tabs behind a bottom nav, same as RE.
/// There's no app bar: each tab draws its own header in the page.
/// Detail screens (farmer detail, the visit hub, visit detail) are pushed
/// OVER this shell; they are not tabs.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0 = Home, 1 = Farmers, 2 = Visits, 3 = Analytics.
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Opened from the ☰ on Home's header, or by swiping in from the
      // left edge on any tab.
      drawer: const AppDrawer(),
      body: SafeArea(
        // IndexedStack keeps every tab alive; switching shows another child
        // without rebuilding it, so scroll positions and typed search text
        // survive tab hops.
        child: IndexedStack(
          index: _index,
          children: const [
            HomeTab(),
            FarmersTab(),
            VisitsTab(),
            AnalyticsTab(),
          ],
        ),
      ),
      // A hairline on top instead of the default elevation shadow: on a
      // light page the shadow looks smudgy, the line looks deliberate.
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: AppColors.white,
          elevation: 0,
          selectedItemColor: AppColors.red,
          unselectedItemColor: AppColors.muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Farmers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Visits',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
          ],
        ),
      ),
    );
  }
}
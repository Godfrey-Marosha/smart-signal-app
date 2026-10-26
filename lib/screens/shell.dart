import 'package:flutter/material.dart';

import 'area_screen.dart';
import 'community_screen.dart';
import 'electricity_screen.dart';
import 'home_screen.dart';
import 'impact_screen.dart';
import 'report_screen.dart';

/// Tab indexes, so other screens can jump to a tab.
class Tabs {
  static const home = 0;
  static const area = 1;
  static const community = 2;
  static const electricity = 3;
  static const me = 4;
}

/// Lets any screen switch tabs: `ShellNav.of(context)?.goTo(Tabs.community)`.
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.goTo, required super.child});
  final void Function(int index) goTo;

  static ShellNav? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellNav>();

  @override
  bool updateShouldNotify(ShellNav oldWidget) => false;
}

void openReport(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen(), fullscreenDialog: true));

/// Five tabs plus the Report button on Home and Area.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = Tabs.home;

  static const _pages = [HomeScreen(), AreaScreen(), CommunityScreen(), ElectricityScreen(), ImpactScreen()];

  /// Tabs are built the first time they're opened, not all five at start-up.
  final Set<int> _visited = {Tabs.home};

  @override
  Widget build(BuildContext context) {
    return ShellNav(
      goTo: (i) => setState(() {
        _index = i;
        _visited.add(i);
      }),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++) _visited.contains(i) ? _pages[i] : const SizedBox.shrink(),
          ],
        ),
        floatingActionButton: _index == Tabs.home || _index == Tabs.area
            ? FloatingActionButton.extended(
                onPressed: () => openReport(context),
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Report'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _visited.add(i);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Area'),
            NavigationDestination(icon: Icon(Icons.diversity_3_outlined), selectedIcon: Icon(Icons.diversity_3), label: 'Community'),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Electricity'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
          ],
        ),
      ),
    );
  }
}

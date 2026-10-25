import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/app_store.dart';
import 'customer_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'sms_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.onLogout});
  final AppStore store;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;

  static const _tabs = <({String label, IconData icon, IconData activeIcon})>[
    (label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded),
    (label: 'Customers', icon: Icons.person_add_alt_outlined, activeIcon: Icons.person_add_alt_1_rounded),
    (label: 'Reports', icon: Icons.insert_chart_outlined_rounded, activeIcon: Icons.insert_chart_rounded),
    (label: 'SMS', icon: Icons.sms_outlined, activeIcon: Icons.sms_rounded),
  ];

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(store: widget.store),
    ));
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No, stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, sign out'),
          ),
        ],
      ),
    ) ?? false;
    if (confirmed && mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final pages = [
      DashboardScreen(store: widget.store),
      CustomerScreen(store: widget.store),
      ReportsScreen(store: widget.store),
      SmsScreen(store: widget.store),
    ];
    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              titleSpacing: 16,
              
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        'assets/logo.jpg',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Caitlyn Laundry Shop',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Laundry management',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _logOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: Row(
        children: [
          if (isWide) _desktopSidebar(),
          Expanded(
            child: SafeArea(
              top: isWide,
              child: IndexedStack(index: _selected, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              height: 74,
              selectedIndex: _selected,
              onDestinationSelected: (index) => setState(() => _selected = index),
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.activeIcon),
                    label: tab.label,
                  ),
              ],
            ),
    );
  }

  Widget _desktopSidebar() => Container(
        width: 250,
        decoration: const BoxDecoration(color: AppColors.navy),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                Row(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/logo.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Caitlyn\nLaundry Shop',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 38),
                for (var index = 0; index < _tabs.length; index++) ...[
                  Material(
                    color: _selected == index
                        ? Colors.white.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Row(
                          children: [
                            Icon(_selected == index
                                    ? _tabs[index].activeIcon
                                    : _tabs[index].icon,
                                color: Colors.white),
                            const SizedBox(width: 13),
                            Text(_tabs[index].label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: _selected == index
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                const Spacer(),
                const Divider(color: Colors.white24),
                TextButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  label: const Text('Settings',
                      style: TextStyle(color: Colors.white)),
                ),
                TextButton.icon(
                  onPressed: _logOut,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: const Text('Sign out', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                const Text('Offline-first • Local Hive storage',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}

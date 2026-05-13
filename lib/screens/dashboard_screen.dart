import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/screens/devices_screen.dart';
import 'package:gnss_app/screens/history_screen.dart';
import 'package:gnss_app/screens/map_screen.dart';
import 'package:gnss_app/screens/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTabIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      MapScreen(),
      DevicesScreen(),
      HistoryScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.bgMainGradientEnd],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedTabIndex),
              child: pages[_selectedTabIndex],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BottomMenuItem(
                    label: 'Map',
                    icon: Icons.map,
                    active: _selectedTabIndex == 0,
                    onTap: () => _selectTab(0),
                  ),
                ),
                Expanded(
                  child: _BottomMenuItem(
                    label: 'Devices',
                    icon: Icons.devices,
                    active: _selectedTabIndex == 1,
                    onTap: () => _selectTab(1),
                  ),
                ),
                Expanded(
                  child: _BottomMenuItem(
                    label: 'History',
                    icon: Icons.bar_chart,
                    active: _selectedTabIndex == 2,
                    onTap: () => _selectTab(2),
                  ),
                ),
                Expanded(
                  child: _BottomMenuItem(
                    label: 'Settings',
                    icon: Icons.person,
                    active: _selectedTabIndex == 3,
                    onTap: () => _selectTab(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _BottomMenuItem extends StatelessWidget {
  const _BottomMenuItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.brandBlue;
    final inactiveColor = const Color(0xFF98A2B3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? activeColor : inactiveColor, size: 24),
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? activeColor : inactiveColor,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

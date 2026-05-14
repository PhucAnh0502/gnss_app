import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/screens/devices_screen.dart';
import 'package:gnss_app/screens/history_screen.dart';
import 'package:gnss_app/screens/map_screen.dart';
import 'package:gnss_app/screens/settings_screen.dart';
import 'package:gnss_app/screens/snapshots_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTabIndex = 0;

  void _selectTab(int index) {
    if (index != _selectedTabIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedTabIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MapScreen(key: const PageStorageKey<String>('map')),
      DevicesScreen(key: const PageStorageKey<String>('devices')),
      const SnapshotsScreen(key: PageStorageKey<String>('snapshots')),
      HistoryScreen(key: const PageStorageKey<String>('history')),
      SettingsScreen(key: const PageStorageKey<String>('settings')),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryDark, AppColors.bgMainGradientEnd],
              stops: [0.0, 0.85],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedTabIndex),
                child: pages[_selectedTabIndex],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: _selectedTabIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _NavItem(icon: Icons.devices_outlined, activeIcon: Icons.devices, label: 'Devices'),
    _NavItem(icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt, label: 'Snapshots'),
    _NavItem(icon: Icons.timeline_outlined, activeIcon: Icons.timeline, label: 'History'),
    _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding > 0 ? bottomPadding : 10),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.slate700.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isActive = index == selectedIndex;
          return _NavBarItem(
            item: item,
            isActive: isActive,
            onTap: () => onTap(index),
          );
        }),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandBlue.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.brandBlue.withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                key: ValueKey(isActive),
                color: isActive ? AppColors.brandBlue : AppColors.slate500,
                size: 21,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.brandBlueLight : AppColors.slate500,
                letterSpacing: -0.1,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

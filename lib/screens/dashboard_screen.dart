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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const bubbleSize = 58.0;
              const barTop = 40.0;
              const horizontalInset = 24.0;
              final slotWidth =
                  (constraints.maxWidth - horizontalInset * 2) / 4;
              final targetCenterX =
                  horizontalInset + slotWidth * (_selectedTabIndex + 0.5);

              return SizedBox(
                height: 110,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: targetCenterX,
                    end: targetCenterX,
                  ),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedCenterX, _) {
                    final notchRadius = bubbleSize / 2 + 10;
                    final centerX = animatedCenterX;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: barTop,
                          left: 0,
                          right: 0,
                          child: ClipPath(
                            clipper: _BottomNavClipper(
                              notchCenterX: centerX,
                              notchRadius: notchRadius,
                              notchDepth: 20,
                            ),
                            child: Container(
                              height: 78,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: horizontalInset,
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
                        ),
                        Positioned(
                          top: -8,
                          left: centerX - (bubbleSize / 2),
                          child: Container(
                            width: bubbleSize,
                            height: bubbleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFDCE1EA),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _activeTabIcon(_selectedTabIndex),
                              color: AppColors.brandBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  IconData _activeTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.map;
      case 1:
        return Icons.devices;
      case 2:
        return Icons.bar_chart;
      case 3:
        return Icons.person;
      default:
        return Icons.map;
    }
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
    final inactiveColor = const Color(0xFFA9B1C2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!active) Icon(icon, color: inactiveColor, size: 24),
          if (!active) const SizedBox(height: 4),
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

class _BottomNavClipper extends CustomClipper<Path> {
  _BottomNavClipper({
    required this.notchCenterX,
    required this.notchRadius,
    required this.notchDepth,
  });

  final double notchCenterX;
  final double notchRadius;
  final double notchDepth;

  @override
  Path getClip(Size size) {
    final path = Path();
    const corner = 28.0;
    const shoulderPadding = 8.0;
    final notchStart = (notchCenterX - notchRadius - shoulderPadding).clamp(
      corner,
      size.width - corner,
    );
    final notchEnd = (notchCenterX + notchRadius + shoulderPadding).clamp(
      corner,
      size.width - corner,
    );

    path.moveTo(corner, 0);
    path.lineTo(notchStart, 0);
    path.cubicTo(
      notchStart + notchRadius * 0.32,
      0,
      notchCenterX - notchRadius * 0.55,
      notchDepth,
      notchCenterX,
      notchDepth,
    );
    path.cubicTo(
      notchCenterX + notchRadius * 0.55,
      notchDepth,
      notchEnd - notchRadius * 0.32,
      0,
      notchEnd,
      0,
    );
    path.lineTo(size.width - corner, 0);
    path.quadraticBezierTo(size.width, 0, size.width, corner);
    path.lineTo(size.width, size.height - corner);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - corner,
      size.height,
    );
    path.lineTo(corner, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - corner);
    path.lineTo(0, corner);
    path.quadraticBezierTo(0, 0, corner, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _BottomNavClipper oldClipper) {
    return oldClipper.notchCenterX != notchCenterX ||
        oldClipper.notchRadius != notchRadius ||
        oldClipper.notchDepth != notchDepth;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/providers/auth_provider.dart';
import 'package:gnss_app/providers/tracking_provider.dart';
import 'package:gnss_app/screens/change_password_screen.dart';
import 'package:gnss_app/screens/login_screen.dart';
import 'package:gnss_app/utils/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final trackingState = ref.watch(trackingProvider);
    final user = authState.user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        // ===== PROFILE HEADER =====
        _ProfileHeader(
          username: user?.username ?? 'User',
          email: user?.email ?? '',
        ),
        const SizedBox(height: 24),

        // ===== TRACKING CARD =====
        _TrackingCard(
          trackingState: trackingState,
          onToggle: (enabled) async {
            final ok = await ref
                .read(trackingProvider.notifier)
                .setTrackingEnabled(enabled);
            if (!ok && context.mounted) {
              AppSnackBar.error(
                context,
                trackingState.errorMessage ?? 'Cannot change tracking state.',
              );
            }
          },
        ),
        const SizedBox(height: 16),

        // ===== SETTINGS SECTION =====
        _SectionTitle(title: 'Account'),
        const SizedBox(height: 10),

        _SettingsTile(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: () {
            Navigator.of(context).pushNamed(ChangePasswordScreen.routeName);
          },
        ),
        const SizedBox(height: 10),

        _SettingsTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'GNSS Vision v1.0.0',
          onTap: () {},
        ),
        const SizedBox(height: 24),

        // ===== LOGOUT =====
        _LogoutButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF16243A),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.2)),
                ),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
                ),
                content: const Text(
                  'Are you sure you want to sign out? Tracking will be stopped.',
                  style: TextStyle(color: AppColors.slate400),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );

            if (confirmed != true || !context.mounted) return;

            await ref.read(trackingProvider.notifier).setTrackingEnabled(false);
            await ref.read(authProvider.notifier).logout();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              LoginScreen.routeName,
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}

// ===== PROFILE HEADER =====
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.username, required this.email});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1D39), Color(0xFF081120)],
        ),
        border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.brandBlue, Color(0xFF67E8F9)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.isNotEmpty ? username : 'User',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== TRACKING CARD =====
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.trackingState,
    required this.onToggle,
  });

  final TrackingState trackingState;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final isTracking = trackingState.isTracking;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0F1629),
        border: Border.all(
          color: isTracking
              ? AppColors.brandBlue.withValues(alpha: 0.3)
              : AppColors.slate700.withValues(alpha: 0.3),
        ),
        boxShadow: isTracking
            ? [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTracking
                      ? AppColors.brandBlue.withValues(alpha: 0.15)
                      : AppColors.slate700.withValues(alpha: 0.3),
                ),
                child: Icon(
                  isTracking ? Icons.satellite_alt : Icons.satellite_outlined,
                  color: isTracking ? AppColors.brandBlue : AppColors.slate500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GNSS Tracking',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTracking ? 'Broadcasting location data' : 'Tracking is paused',
                      style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isTracking,
                activeTrackColor: AppColors.brandBlue,
                onChanged: trackingState.isBusy ? null : onToggle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                label: isTracking ? 'Active' : 'Stopped',
                color: isTracking ? AppColors.success : AppColors.slate500,
              ),
              _MiniChip(
                label: trackingState.isMqttConnected
                    ? 'MQTT Connected'
                    : trackingState.isMqttConnecting
                        ? 'Connecting...'
                        : 'MQTT Off',
                color: trackingState.isMqttConnected
                    ? AppColors.success
                    : AppColors.slate500,
              ),
              if (trackingState.deviceCode != null)
                _MiniChip(
                  label: trackingState.deviceCode!,
                  color: AppColors.brandBlue,
                ),
            ],
          ),
          if (trackingState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.error.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Text(
                trackingState.errorMessage!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===== SECTION TITLE =====
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.slate500,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ===== SETTINGS TILE =====
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0F1629),
            border: Border.all(color: AppColors.slate700.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.slate700.withValues(alpha: 0.3),
                ),
                child: Icon(icon, color: AppColors.slate300, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.slate500, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== LOGOUT BUTTON =====
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.red.shade900.withValues(alpha: 0.15),
            border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 10),
              Text(
                'Sign out',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== MINI CHIP =====
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

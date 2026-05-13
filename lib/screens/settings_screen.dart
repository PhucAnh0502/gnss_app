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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text(
          'Welcome ${user?.username.isNotEmpty == true ? user!.username : 'User'}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(user?.email ?? '', style: const TextStyle(color: AppColors.slate400)),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.bgSidebar.withValues(alpha: 0.7),
            border: Border.all(color: AppColors.slate400.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'Protected route is active. Only authenticated users can view this page.',
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandBlue.withValues(alpha: 0.22),
                AppColors.bgSidebar.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(
              color: trackingState.isTracking
                  ? AppColors.brandBlue.withValues(alpha: 0.45)
                  : AppColors.slate400.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: trackingState.isTracking
                          ? AppColors.brandBlue.withValues(alpha: 0.22)
                          : AppColors.slate400.withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      trackingState.isTracking ? Icons.wifi : Icons.wifi_off,
                      color: trackingState.isTracking
                          ? Colors.lightBlueAccent
                          : AppColors.slate400,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Broker Tracking',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    value: trackingState.isTracking,
                    onChanged: trackingState.isBusy
                        ? null
                        : (enabled) async {
                            final ok = await ref
                                .read(trackingProvider.notifier)
                                .setTrackingEnabled(enabled);
                            if (!ok && context.mounted) {
                              AppSnackBar.error(
                                context,
                                trackingState.errorMessage ??
                                    'Không thể thay đổi trạng thái tracking.',
                              );
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusChip(
                    label: trackingState.isTracking ? 'Running' : 'Stopped',
                    color: trackingState.isTracking
                        ? Colors.greenAccent
                        : AppColors.slate400,
                  ),
                  _StatusChip(
                    label: trackingState.isMqttConnected
                        ? 'MQTT Connected'
                        : trackingState.isMqttConnecting
                            ? 'MQTT Connecting'
                            : 'MQTT Disconnected',
                    color: trackingState.isMqttConnected
                        ? Colors.greenAccent
                        : AppColors.slate400,
                  ),
                  _StatusChip(
                    label: 'Device ${trackingState.deviceCode ?? '-'}',
                    color: AppColors.slate400,
                  ),
                ],
              ),
              if (trackingState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  trackingState.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pushNamed(ChangePasswordScreen.routeName);
          },
          child: const Text('Change Password'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await ref.read(trackingProvider.notifier).setTrackingEnabled(false);
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushNamedAndRemoveUntil(
                LoginScreen.routeName,
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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

  Future<String> _resolveAndroidDeviceCode() async {
    if (!Platform.isAndroid) {
      return '';
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.id.trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final trackingState = ref.watch(trackingProvider);
    final user = authState.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.bgSidebar.withValues(alpha: 0.7),
              border: Border.all(color: AppColors.slate400.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Device Tracking Publisher',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Start để tự publish telemetry bằng deviceCode của chính máy Android này.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tracking: ${trackingState.isTracking ? 'Running' : 'Stopped'}',
                  style: TextStyle(
                    color: trackingState.isTracking
                        ? Colors.greenAccent.shade400
                        : AppColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'MQTT: ${trackingState.isMqttConnected ? 'Connected' : (trackingState.isMqttConnecting ? 'Connecting...' : 'Disconnected')}',
                  style: TextStyle(
                    color: trackingState.isMqttConnected
                        ? Colors.greenAccent.shade400
                        : AppColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Device code: ${trackingState.deviceCode ?? '-'}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trackingState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    trackingState.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: trackingState.isTracking
                            ? null
                            : () async {
                                final deviceCode = await _resolveAndroidDeviceCode();
                                if (deviceCode.isEmpty) {
                                  AppSnackBar.error(
                                    context,
                                    'Cannot resolve Android device code on this device.',
                                  );
                                  return;
                                }

                                await ref
                                    .read(trackingProvider.notifier)
                                    .startTracking(deviceCode: deviceCode);
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Tracking'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: trackingState.isTracking
                            ? () async {
                                await ref
                                    .read(trackingProvider.notifier)
                                    .stopTracking();
                              }
                            : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
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
      ),
    );
  }
}

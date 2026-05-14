import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/providers/auto_capture_provider.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/services/auto_capture_service.dart';

/// A card widget for configuring auto-capture settings.
/// Can be placed in Settings screen or Snapshots screen.
class AutoCaptureSettings extends ConsumerWidget {
  const AutoCaptureSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(autoCaptureProvider);
    final notifier = ref.read(autoCaptureProvider.notifier);
    final devicesAsync = ref.watch(realtimeDevicesProvider);

    if (state.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.bgSidebar.withValues(alpha: 0.72),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 18, color: AppColors.brandBlue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto Capture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textLight)),
                    SizedBox(height: 2),
                    Text('Automatically capture photos with GNSS data', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
              ),
              Switch(
                value: state.enabled,
                onChanged: (value) => notifier.setEnabled(value),
              ),
            ],
          ),

          // Settings (only shown when enabled)
          if (state.enabled) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.slate700, height: 1),
            const SizedBox(height: 16),

            // Device selector
            const Text('Device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
            const SizedBox(height: 8),
            devicesAsync.when(
              loading: () => const SizedBox(height: 48),
              error: (_, __) => const Text('Failed to load devices', style: TextStyle(color: AppColors.errorLight, fontSize: 12)),
              data: (devices) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1730),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.deviceId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F1A30),
                      borderRadius: BorderRadius.circular(14),
                      hint: const Text('Select device', style: TextStyle(color: AppColors.slate500, fontSize: 13)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400, size: 20),
                      style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                      items: devices.map((device) {
                        return DropdownMenuItem<String>(
                          value: device.id,
                          child: Text('${device.deviceName} (${device.deviceCode})'),
                        );
                      }).toList(),
                      onChanged: (value) => notifier.setDeviceId(value),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Mode selector
            const Text('Capture Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ModeOption(
                    label: 'Timer',
                    icon: Icons.timer_outlined,
                    isSelected: state.mode == AutoCaptureMode.timer,
                    onTap: () => notifier.setMode(AutoCaptureMode.timer),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeOption(
                    label: 'Distance',
                    icon: Icons.straighten_outlined,
                    isSelected: state.mode == AutoCaptureMode.distance,
                    onTap: () => notifier.setMode(AutoCaptureMode.distance),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Interval / Distance value
            if (state.mode == AutoCaptureMode.timer) ...[
              const Text('Interval (seconds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
              const SizedBox(height: 8),
              _ValueSelector(
                value: state.intervalSeconds,
                options: const [10, 30, 60, 120, 300, 600],
                labels: const ['10s', '30s', '1m', '2m', '5m', '10m'],
                onChanged: (v) => notifier.setInterval(v),
              ),
            ] else ...[
              const Text('Distance (meters)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
              const SizedBox(height: 8),
              _ValueSelector(
                value: state.distanceMeters.toInt(),
                options: const [50, 100, 200, 500, 1000],
                labels: const ['50m', '100m', '200m', '500m', '1km'],
                onChanged: (v) => notifier.setDistance(v.toDouble()),
              ),
            ],
            const SizedBox(height: 16),

            // Quality
            const Text('Photo Quality', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
            const SizedBox(height: 8),
            Row(
              children: [
                _QualityChip(label: 'Low', isSelected: state.quality == 'low', onTap: () => notifier.setQuality('low')),
                const SizedBox(width: 8),
                _QualityChip(label: 'Medium', isSelected: state.quality == 'medium', onTap: () => notifier.setQuality('medium')),
                const SizedBox(width: 8),
                _QualityChip(label: 'High', isSelected: state.quality == 'high', onTap: () => notifier.setQuality('high')),
              ],
            ),
            const SizedBox(height: 14),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.infoLight),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Auto capture runs when tracking is active. Restart tracking after changing settings.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.label, required this.icon, required this.isSelected, required this.onTap});

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.12) : const Color(0xFF0B1730),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.4) : AppColors.slate700.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppColors.brandBlue : AppColors.slate500),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.brandBlueLight : AppColors.slate400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueSelector extends StatelessWidget {
  const _ValueSelector({required this.value, required this.options, required this.labels, required this.onChanged});

  final int value;
  final List<int> options;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(options[i]),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.15) : const Color(0xFF0B1730),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.4) : AppColors.slate700.withValues(alpha: 0.25)),
              ),
              child: Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.brandBlueLight : AppColors.slate400)),
            ),
          ),
        );
      }),
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.15) : const Color(0xFF0B1730),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.brandBlue.withValues(alpha: 0.4) : AppColors.slate700.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.brandBlueLight : AppColors.slate400)),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/widgets/live_devices_map.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(realtimeDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    // Handle loading state
    if (devicesAsync.isLoading) {
      return const _LoadingState();
    }

    // Handle error state
    if (devicesAsync.hasError) {
      return _ErrorState(error: devicesAsync.error.toString());
    }

    final devices = devicesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <DeviceModel>[],
    );
    final effectiveDevice = selectedDevice ?? (devices.isNotEmpty ? devices.first : null);

    if (effectiveDevice == null) {
      return const _EmptyState(
        icon: Icons.map_outlined,
        title: 'No device selected',
        subtitle: 'Open Devices and choose a tracker to view its route on the map.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(realtimeDevicesProvider);
          await ref.read(realtimeDevicesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _MapHeader(
              deviceName: effectiveDevice.deviceName,
              deviceCode: effectiveDevice.deviceCode,
              status: effectiveDevice.status,
              onDeviceSelected: devices.isEmpty
                  ? null
                  : (device) {
                      ref.read(selectedDeviceProvider.notifier).state = device;
                    },
              devices: devices,
              selectedDeviceId: effectiveDevice.id,
            ),
            const SizedBox(height: 16),
            Container(
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.slate400.withValues(alpha: 0.15)),
              ),
              child: LiveDevicesMap(
                devices: devices,
                selectedDeviceId: effectiveDevice.id,
                onDeviceSelected: (device) {
                  ref.read(selectedDeviceProvider.notifier).state = device;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.deviceName,
    required this.deviceCode,
    required this.status,
    required this.devices,
    required this.selectedDeviceId,
    required this.onDeviceSelected,
  });

  final String deviceName;
  final String deviceCode;
  final String status;
  final List<DeviceModel> devices;
  final String selectedDeviceId;
  final ValueChanged<DeviceModel>? onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1D39), Color(0xFF081120)],
        ),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.brandBlue, Color(0xFF67E8F9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.map_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: $deviceCode',
                      style: const TextStyle(color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 14),
          if (devices.isNotEmpty)
            _DeviceSwitcher(
              devices: devices,
              selectedDeviceId: selectedDeviceId,
              onChanged: onDeviceSelected,
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = normalized == 'active'
        ? Colors.green.shade400
        : normalized == 'maintenance'
            ? Colors.orange.shade400
            : AppColors.slate400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        normalized.isEmpty ? 'Unknown' : normalized[0].toUpperCase() + normalized.substring(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _DeviceSwitcher extends StatelessWidget {
  const _DeviceSwitcher({
    required this.devices,
    required this.selectedDeviceId,
    required this.onChanged,
  });

  final List<DeviceModel> devices;
  final String selectedDeviceId;
  final ValueChanged<DeviceModel>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedDeviceId,
      decoration: InputDecoration(
        labelText: 'Device',
        labelStyle: const TextStyle(color: AppColors.slate400),
        filled: true,
        fillColor: const Color(0xFF0B1730),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.slate400.withValues(alpha: 0.14)),
        ),
      ),
      dropdownColor: const Color(0xFF0B1730),
      style: const TextStyle(color: AppColors.textLight),
      iconEnabledColor: AppColors.slate400,
      items: devices
          .map(
            (device) => DropdownMenuItem<String>(
              value: device.id,
              child: Text(device.deviceName),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (value) {
              final device = devices.firstWhere(
                (item) => item.id == value,
                orElse: () => devices.first,
              );
              onChanged?.call(device);
            },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppColors.bgSidebar.withValues(alpha: 0.72),
          border: Border.all(color: AppColors.slate400.withValues(alpha: 0.16)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.brandBlue, size: 54),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 14,
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

class _LoadingState extends StatefulWidget {
  const _LoadingState();

  @override
  State<_LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<_LoadingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating circle
                RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandBlue.withValues(alpha: 0.2),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                // Inner rotating circle (opposite direction)
                RotationTransition(
                  turns: Tween<double>(begin: 1, end: 0).animate(_controller),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brandBlue.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Center dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Loading devices...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetching your tracker locations',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load devices',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.red.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade300,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Please try again later',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

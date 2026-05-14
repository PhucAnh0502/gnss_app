import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/models/snapshot_model.dart';
import 'package:gnss_app/models/tracking_point_model.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/providers/snapshot_provider.dart';
import 'package:gnss_app/providers/tracking_history_provider.dart';
import 'package:gnss_app/widgets/tracking_history_section.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedDeviceId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String? _lastSnapshotLoadKey;

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(realtimeDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final snapshotState = ref.watch(snapshotProvider);
    final devices = devicesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <DeviceModel>[],
    );

    final effectiveDeviceId = _selectedDeviceId ?? selectedDevice?.id ?? (devices.isNotEmpty ? devices.first.id : null);
    final effectiveDevice = effectiveDeviceId == null
        ? null
        : devices.where((device) => device.id == effectiveDeviceId).cast<DeviceModel?>().firstWhere(
              (device) => device != null,
              orElse: () => selectedDevice,
            );

    final queryKey = effectiveDeviceId == null
        ? null
        : '${effectiveDeviceId}|${_startDate.toUtc().toIso8601String()}|${_endDate.toUtc().toIso8601String()}';
    final historyAsync = queryKey == null
        ? const AsyncValue<TrackingHistoryBundle>.loading()
        : ref.watch(trackingHistoryRangeProvider(queryKey));

    if (queryKey != null && _lastSnapshotLoadKey != queryKey) {
      _lastSnapshotLoadKey = queryKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && effectiveDeviceId != null) {
          ref.read(snapshotProvider.notifier).loadSnapshots(
                effectiveDeviceId,
                from: _startDate.toUtc(),
                to: _endDate.toUtc(),
              );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: ListView(
        children: [
          const Text(
            'Tracking History',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View and filter detailed location history for your devices.',
            style: const TextStyle(color: AppColors.slate400),
          ),
          const SizedBox(height: 16),
          _HistoryFiltersCard(
            devices: devices,
            selectedDeviceId: effectiveDeviceId,
            startDate: _startDate,
            endDate: _endDate,
            onSelectedDeviceChange: (value) {
              setState(() {
                _selectedDeviceId = value;
                final picked = devices.where((device) => device.id == value).toList();
                if (picked.isNotEmpty) {
                  ref.read(selectedDeviceProvider.notifier).state = picked.first;
                }
              });
            },
            onStartDateChange: (date) {
              setState(() {
                _startDate = date;
              });
            },
            onEndDateChange: (date) {
              setState(() {
                _endDate = date;
              });
            },
            onSearch: () {
              if (queryKey != null) {
                ref.invalidate(trackingHistoryRangeProvider(queryKey));
              }
            },
            onQuickRangeSelected: (days) {
              setState(() {
                _startDate = DateTime.now().subtract(Duration(days: days));
                _endDate = DateTime.now();
              });
            },
            selectedRangeLabel: _rangeLabel(_startDate, _endDate),
          ),
          if (effectiveDeviceId != null) ...[
            const SizedBox(height: 16),
            _SnapshotHistoryBanner(
              snapshotCount: snapshotState.items.where((item) => item.deviceId == effectiveDeviceId).length,
              isLoading: snapshotState.isLoading,
              lastSnapshot: snapshotState.items.where((item) => item.deviceId == effectiveDeviceId).isEmpty
                  ? null
                  : snapshotState.items.where((item) => item.deviceId == effectiveDeviceId).first,
            ),
          ],
          const SizedBox(height: 16),
          if (historyAsync.isLoading)
            const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (historyAsync.hasError)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bgSidebar.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
              ),
              child: Text(
                historyAsync.error.toString(),
                style: const TextStyle(color: AppColors.slate400),
              ),
            )
          else if (effectiveDevice == null)
            const SizedBox.shrink()
          else
            TrackingHistorySection(
              device: effectiveDevice,
              bundle: historyAsync.value ?? const TrackingHistoryBundle(points: [], totalDistanceMeters: 0, pointCount: 0),
              selectedRangeDays: _rangeDays(_startDate, _endDate),
              onRangeSelected: (days) {
                setState(() {
                  _startDate = DateTime.now().subtract(Duration(days: days));
                  _endDate = DateTime.now();
                });
              },
              showRangeChips: false,
            ),
        ],
      ),
    );
  }

  int _rangeDays(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days <= 0 ? 1 : days;
  }

  String _rangeLabel(DateTime start, DateTime end) {
    final days = _rangeDays(start, end);
    if (days == 1) {
      return '24h';
    }
    if (days <= 7) {
      return '$days days';
    }
    return '${days ~/ 7} weeks';
  }
}

class _HistoryFiltersCard extends StatelessWidget {
  const _HistoryFiltersCard({
    required this.devices,
    required this.selectedDeviceId,
    required this.startDate,
    required this.endDate,
    required this.onSelectedDeviceChange,
    required this.onStartDateChange,
    required this.onEndDateChange,
    required this.onSearch,
    required this.onQuickRangeSelected,
    required this.selectedRangeLabel,
  });

  final List<DeviceModel> devices;
  final String? selectedDeviceId;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<String?> onSelectedDeviceChange;
  final ValueChanged<DateTime> onStartDateChange;
  final ValueChanged<DateTime> onEndDateChange;
  final VoidCallback onSearch;
  final ValueChanged<int> onQuickRangeSelected;
  final String selectedRangeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.bgSidebar.withValues(alpha: 0.72),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedDeviceId,
            decoration: _fieldDecoration('Select device'),
            dropdownColor: const Color(0xFF0B1730),
            style: const TextStyle(color: AppColors.textLight),
            items: devices
                .map(
                  (device) => DropdownMenuItem<String>(
                    value: device.id,
                    child: Text('${device.deviceName} (${device.deviceCode})'),
                  ),
                )
                .toList(),
            onChanged: onSelectedDeviceChange,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Start date',
                  value: _formatDate(startDate),
                  onTap: () => _pickDate(context, startDate, (date) => onStartDateChange(date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'End date',
                  value: _formatDate(endDate),
                  onTap: () => _pickDate(context, endDate, (date) => onEndDateChange(date)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: selectedDeviceId == null ? null : onSearch,
                  child: const Text('Search History'),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.slate400),
      filled: true,
      fillColor: const Color(0xFF0B1730),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.slate400.withValues(alpha: 0.14)),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime initialDate,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }
}

class _SnapshotHistoryBanner extends StatelessWidget {
  const _SnapshotHistoryBanner({
    required this.snapshotCount,
    required this.isLoading,
    required this.lastSnapshot,
  });

  final int snapshotCount;
  final bool isLoading;
  final SnapshotModel? lastSnapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.bgSidebar.withValues(alpha: 0.72),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: AppColors.brandBlue, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Snapshot activity',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLoading)
                const Text('Refreshing...', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SnapshotInfoTile(label: 'Loaded', value: snapshotCount.toString())),
              const SizedBox(width: 12),
              Expanded(child: _SnapshotInfoTile(label: 'Latest status', value: lastSnapshot?.syncStatus ?? 'none')),
              const SizedBox(width: 12),
              Expanded(child: _SnapshotInfoTile(label: 'Mode', value: lastSnapshot?.captureMode ?? '-')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotInfoTile extends StatelessWidget {
  const _SnapshotInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF0B1730),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1730),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate400.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.slate400, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


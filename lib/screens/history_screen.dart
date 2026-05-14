import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/models/tracking_point_model.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/providers/tracking_history_provider.dart';
import 'package:gnss_app/widgets/collapsible_filter_card.dart';
import 'package:gnss_app/widgets/datetime_picker_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(realtimeDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);
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
        : '$effectiveDeviceId|${_startDate.toUtc().toIso8601String()}|${_endDate.toUtc().toIso8601String()}';
    final historyAsync = queryKey == null
        ? const AsyncValue<TrackingHistoryBundle>.loading()
        : ref.watch(trackingHistoryRangeProvider(queryKey));

    final deviceName = effectiveDeviceId == null
        ? 'No device'
        : devices.where((d) => d.id == effectiveDeviceId).map((d) => d.deviceName).firstOrNull ?? 'Device';
    final rangeSummary = _buildRangeSummary();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: ListView(
        children: [
          const Text(
            'Tracking History',
            style: TextStyle(color: AppColors.textLight, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),

          // Collapsible Filters
          CollapsibleFilterCard(
            title: 'Filters',
            summary: '$deviceName · $rangeSummary',
            child: _buildFilterContent(devices, effectiveDeviceId, queryKey),
          ),

          const SizedBox(height: 16),
          if (historyAsync.isLoading)
            const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))
          else if (historyAsync.hasError)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bgSidebar.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.28)),
              ),
              child: Text(historyAsync.error.toString(), style: const TextStyle(color: AppColors.slate400)),
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

  Widget _buildFilterContent(List<DeviceModel> devices, String? effectiveDeviceId, String? queryKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // Device selector
        DropdownButtonFormField<String>(
          value: effectiveDeviceId,
          decoration: InputDecoration(
            labelText: 'Device',
            labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF0B1730),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.slate400.withValues(alpha: 0.14))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.slate400.withValues(alpha: 0.14))),
          ),
          dropdownColor: const Color(0xFF0B1730),
          style: const TextStyle(color: AppColors.textLight, fontSize: 13),
          items: devices.map((device) => DropdownMenuItem<String>(value: device.id, child: Text('${device.deviceName} (${device.deviceCode})'))).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDeviceId = value;
              final picked = devices.where((d) => d.id == value).toList();
              if (picked.isNotEmpty) {
                ref.read(selectedDeviceProvider.notifier).state = picked.first;
              }
            });
          },
        ),
        const SizedBox(height: 14),

        // Date-time range display + picker trigger
        _DateTimeRangeTile(
          from: _startDate,
          to: _endDate,
          onTap: () => _openDateTimePicker(),
        ),
      ],
    );
  }

  Future<void> _openDateTimePicker() async {
    final result = await DateTimePickerSheet.show(
      context,
      initialFrom: _startDate,
      initialTo: _endDate,
    );
    if (result != null) {
      setState(() {
        _startDate = result.from;
        _endDate = result.to;
      });
      // Auto-search after applying
      final effectiveDeviceId = _selectedDeviceId ?? ref.read(selectedDeviceProvider)?.id;
      if (effectiveDeviceId != null) {
        final queryKey = '$effectiveDeviceId|${_startDate.toUtc().toIso8601String()}|${_endDate.toUtc().toIso8601String()}';
        ref.invalidate(trackingHistoryRangeProvider(queryKey));
      }
    }
  }

  String _buildRangeSummary() {
    final diff = _endDate.difference(_startDate);
    if (diff.inHours <= 1) return '1h';
    if (diff.inHours <= 6) return '${diff.inHours}h';
    if (diff.inHours <= 24) return '24h';
    return '${diff.inDays}d';
  }

  int _rangeDays(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days <= 0 ? 1 : days;
  }
}

// ===== DATE TIME RANGE TILE =====
class _DateTimeRangeTile extends StatelessWidget {
  const _DateTimeRangeTile({required this.from, required this.to, required this.onTap});

  final DateTime from;
  final DateTime to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1730),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Calendar icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.date_range_rounded, size: 18, color: AppColors.brandBlue),
              ),
              const SizedBox(width: 12),
              // Range text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('From  ', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                        Text(_formatDt(from), style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('To      ', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                        Text(_formatDt(to), style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDt(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.year}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

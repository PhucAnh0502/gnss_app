import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/models/snapshot_model.dart';
import 'package:gnss_app/providers/snapshot_provider.dart';
import 'package:gnss_app/providers/device_provider.dart';
import 'package:gnss_app/widgets/collapsible_filter_card.dart';
import 'package:gnss_app/widgets/datetime_picker_sheet.dart';
import 'package:gnss_app/widgets/snapshot_detail_modal.dart';

class SnapshotsScreen extends ConsumerStatefulWidget {
  const SnapshotsScreen({super.key});

  @override
  ConsumerState<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends ConsumerState<SnapshotsScreen> {
  String? _selectedDeviceId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDevice());
  }

  void _initDevice() {
    final devicesAsync = ref.read(realtimeDevicesProvider);
    devicesAsync.whenData((devices) {
      if (devices.isNotEmpty && _selectedDeviceId == null) {
        setState(() => _selectedDeviceId = devices.first.id);
        _loadSnapshots();
      }
    });
  }

  Future<void> _loadSnapshots() async {
    if (_selectedDeviceId == null) return;
    await ref.read(snapshotProvider.notifier).loadSnapshots(
      _selectedDeviceId!,
      from: _startDate.toUtc(),
      to: _endDate.toUtc(),
    );
  }

  void _onDeviceChanged(String? deviceId) {
    if (deviceId == null || deviceId == _selectedDeviceId) return;
    setState(() => _selectedDeviceId = deviceId);
    _loadSnapshots();
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
      _loadSnapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotState = ref.watch(snapshotProvider);
    final devicesAsync = ref.watch(realtimeDevicesProvider);

    // Auto-select first device
    devicesAsync.whenData((devices) {
      if (devices.isNotEmpty && _selectedDeviceId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _selectedDeviceId = devices.first.id);
          _loadSnapshots();
        });
      }
    });

    final deviceName = devicesAsync.whenOrNull(
      data: (devices) => devices.where((d) => d.id == _selectedDeviceId).map((d) => d.deviceName).firstOrNull,
    ) ?? 'No device';
    final rangeSummary = _buildRangeSummary();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text('Snapshots', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: -0.5)),
              ),
              _GlassIconButton(icon: Icons.refresh_rounded, isLoading: snapshotState.isLoading, onTap: _loadSnapshots),
            ],
          ),
          const SizedBox(height: 14),

          // Collapsible filter card
          CollapsibleFilterCard(
            title: 'Filters',
            summary: '$deviceName · $rangeSummary',
            child: _buildFilterContent(devicesAsync),
          ),
          const SizedBox(height: 14),

          // Content
          Expanded(child: _buildContent(snapshotState)),
        ],
      ),
    );
  }

  Widget _buildFilterContent(AsyncValue<List<DeviceModel>> devicesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // Device selector
        _buildDeviceSelector(devicesAsync),
        const SizedBox(height: 12),

        // Date-time range tile
        _DateTimeRangeTile(
          from: _startDate,
          to: _endDate,
          onTap: _openDateTimePicker,
        ),
      ],
    );
  }

  Widget _buildDeviceSelector(AsyncValue<List<DeviceModel>> devicesAsync) {
    return devicesAsync.when(
      loading: () => const SizedBox(height: 48, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate500)))),
      error: (_, __) => const Row(children: [Icon(Icons.error_outline, size: 16, color: AppColors.errorLight), SizedBox(width: 8), Text('Failed to load devices', style: TextStyle(fontSize: 12, color: AppColors.errorLight))]),
      data: (devices) {
        if (devices.isEmpty) {
          return const Row(children: [Icon(Icons.info_outline, size: 16, color: AppColors.slate400), SizedBox(width: 8), Text('No devices', style: TextStyle(fontSize: 12, color: AppColors.slate400))]);
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1730),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeviceId,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F1A30),
              borderRadius: BorderRadius.circular(14),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slate400, size: 20),
              style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontFamily: 'Inter'),
              items: devices.map((device) {
                return DropdownMenuItem<String>(
                  value: device.id,
                  child: Row(
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: device.status == 'active' ? AppColors.success : AppColors.slate600)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(device.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLight), overflow: TextOverflow.ellipsis)),
                      Text(device.deviceCode, style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontFamily: 'monospace')),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _onDeviceChanged,
            ),
          ),
        );
      },
    );
  }

  String _buildRangeSummary() {
    final diff = _endDate.difference(_startDate);
    if (diff.inHours <= 1) return '1h';
    if (diff.inHours <= 6) return '${diff.inHours}h';
    if (diff.inHours <= 24) return '24h';
    return '${diff.inDays}d';
  }

  Widget _buildContent(SnapshotState state) {
    if (_selectedDeviceId == null) return _buildEmptyState(Icons.devices_outlined, 'No device selected', 'Choose a device above.');
    if (state.isLoading && state.items.isEmpty) return const Center(child: CircularProgressIndicator(color: AppColors.brandBlue, strokeWidth: 2.5));
    if (state.errorMessage != null && state.items.isEmpty) return _buildEmptyState(Icons.error_outline_rounded, 'Failed to load', state.errorMessage!);
    if (state.items.isEmpty) return _buildEmptyState(Icons.camera_alt_outlined, 'No snapshots', 'No snapshots found in the selected range.');

    return RefreshIndicator(
      onRefresh: _loadSnapshots,
      color: AppColors.brandBlue,
      backgroundColor: AppColors.bgCard,
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        itemCount: state.items.length,
        itemBuilder: (context, index) => _SnapshotCard(snapshot: state.items[index], onTap: () => _showDetail(state.items[index])),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.bgCard.withValues(alpha: 0.5), shape: BoxShape.circle, border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3))),
            child: Icon(icon, size: 36, color: AppColors.slate500),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.slate400)),
        ],
      ),
    );
  }

  void _showDetail(SnapshotModel snapshot) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => SnapshotDetailModal(snapshot: snapshot));
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.date_range_rounded, size: 18, color: AppColors.brandBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('From  ', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                      Text(_formatDt(from), style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('To      ', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w500)),
                      Text(_formatDt(to), style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
                    ]),
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

// ===== GLASS ICON BUTTON =====
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap, this.isLoading = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.bgCard.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3))),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandBlue))
              : Icon(icon, size: 18, color: AppColors.slate300),
        ),
      ),
    );
  }
}

// ===== SNAPSHOT CARD =====
class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot, required this.onTap});

  final SnapshotModel snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.slate700.withValues(alpha: 0.3))),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  Positioned(bottom: 0, left: 0, right: 0, height: 40, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)])))),
                  Positioned(top: 8, left: 8, child: _buildStatusBadge()),
                  Positioned(top: 8, right: 8, child: _buildModeBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(snapshot.capturedAt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.slate500),
                    const SizedBox(width: 3),
                    Expanded(child: Text(_formatLocation(), style: const TextStyle(fontSize: 10, color: AppColors.slate400), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (snapshot.imageUrl != null && snapshot.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(imageUrl: snapshot.imageUrl!, fit: BoxFit.cover, placeholder: (_, __) => Container(color: AppColors.bgSidebar, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate500)))), errorWidget: (_, __, ___) => Container(color: AppColors.bgSidebar, child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.slate600, size: 28))));
    }
    return Container(color: AppColors.bgSidebar, child: const Center(child: Icon(Icons.image_outlined, color: AppColors.slate600, size: 32)));
  }

  Widget _buildStatusBadge() {
    final status = snapshot.syncStatus.toLowerCase();
    final color = status == 'synced' ? AppColors.success : status == 'uploaded' ? AppColors.brandBlue : status == 'failed' ? AppColors.error : AppColors.warning;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.4))), child: Text(snapshot.syncStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)));
  }

  Widget _buildModeBadge() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(6)), child: Text(snapshot.captureMode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.slate300, letterSpacing: 0.3)));
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatLocation() {
    if (snapshot.latitude != null && snapshot.longitude != null) return '${snapshot.latitude!.toStringAsFixed(5)}, ${snapshot.longitude!.toStringAsFixed(5)}';
    return 'No location';
  }
}

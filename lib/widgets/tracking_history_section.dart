import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/providers/snapshot_provider.dart';
import 'package:gnss_app/models/tracking_point_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class TrackingHistorySection extends ConsumerWidget {
  const TrackingHistorySection({
    super.key,
    required this.device,
    required this.bundle,
    required this.selectedRangeDays,
    required this.onRangeSelected,
    this.showRangeChips = true,
  });

  final DeviceModel? device;
  final TrackingHistoryBundle bundle;
  final int selectedRangeDays;
  final ValueChanged<int> onRangeSelected;
  final bool showRangeChips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPoints = bundle.hasPoints;
    final snapshotState = device == null ? null : ref.watch(snapshotProvider);
    final snapshots = device == null
        ? const []
        : snapshotState!.items.where((item) => item.deviceId == device!.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Journey on map',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device == null
                        ? 'Select a device to inspect its recent route.'
                        : '${device!.deviceName} • ${bundle.pointCount} points',
                    style: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                ],
              ),
            ),
            _StatusPill(
              label: device == null ? 'No device' : _statusLabel(device!.status),
              color: _statusColor(device?.status),
            ),
          ],
        ),
        if (showRangeChips) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RangeChip(
                label: '24h',
                selected: selectedRangeDays == 1,
                onTap: () => onRangeSelected(1),
              ),
              _RangeChip(
                label: '7d',
                selected: selectedRangeDays == 7,
                onTap: () => onRangeSelected(7),
              ),
              _RangeChip(
                label: '30d',
                selected: selectedRangeDays == 30,
                onTap: () => onRangeSelected(30),
              ),
              _RangeChip(
                label: 'All available',
                selected: false,
                onTap: () => onRangeSelected(30),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1530), Color(0xFF081226)],
            ),
            border: Border.all(color: AppColors.slate400.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: _HistoryMap(points: bundle.points),
        ),
        const SizedBox(height: 16),
        Text(
          'Recent points',
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (snapshots.isNotEmpty) ...[
          Text(
            'Snapshots',
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final snapshot = snapshots[index];
                return Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSidebar.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate400.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.captureMode, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                      const SizedBox(height: 6),
                      Text(snapshot.capturedAt.toLocal().toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(snapshot.syncStatus, style: const TextStyle(color: AppColors.brandBlue, fontSize: 11)),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: snapshots.length,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (!hasPoints)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgSidebar.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.slate400.withValues(alpha: 0.16)),
            ),
            child: const Text(
              'No tracking points found in the selected time range.',
              style: TextStyle(color: AppColors.slate400),
            ),
          )
        else
          ...bundle.points.reversed.take(5).map(
                (point) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSidebar.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.slate400.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.brandBlue, Color(0xFF67E8F9)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandBlue.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.place, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.timeLabel,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${point.speed.toStringAsFixed(1)} km/h',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              point.dateLabel,
                              style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'active':
        return Colors.green.shade400;
      case 'maintenance':
        return Colors.orange.shade400;
      case 'inactive':
      default:
        return AppColors.slate400;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandBlue : const Color(0xFF0D1932),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.brandBlue.withValues(alpha: 0.7)
                : AppColors.slate400.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.slate400,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryMap extends StatefulWidget {
  const _HistoryMap({required this.points});

  final List<TrackingPointModel> points;

  @override
  State<_HistoryMap> createState() => _HistoryMapState();
}

class _HistoryMapState extends State<_HistoryMap> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(_HistoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Khi tracking data thay đổi (chọn range mới), tự động fit zoom về route
    if (oldWidget.points != widget.points && widget.points.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), _autoFitToRoute);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _autoFitToRoute() async {
    final validPoints = widget.points
        .where((point) => point.latitude.isFinite && point.longitude.isFinite)
        .toList();

    if (validPoints.isEmpty) return;

    final mapPoints = validPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    await _fitToRoute(mapPoints);
  }

  Future<void> _fitToRoute(List<LatLng> points) async {
    if (points.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(28),
      ),
    );
  }

  Future<void> _centerOnLastMarker() async {
    final validPoints = widget.points
        .where((point) => point.latitude.isFinite && point.longitude.isFinite)
        .toList();

    if (validPoints.isEmpty) return;

    final lastPoint = LatLng(validPoints.last.latitude, validPoints.last.longitude);
    _mapController.move(lastPoint, 17);
  }

  Marker _buildMarker(BuildContext ctx, LatLng point, Color color, String label) {
    return Marker(
      point: point,
      width: 28,
      height: 28,
      child: GestureDetector(
        onTap: () => _showMarkerInfo(ctx, point, color, label),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.95),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkerInfo(BuildContext ctx, LatLng point, Color color, String label) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0D1932),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                color: AppColors.slate400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = widget.points
        .where((point) => point.latitude.isFinite && point.longitude.isFinite)
        .toList();

    final mapOptions = _buildMapOptions(validPoints);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: mapOptions,
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'gnss_app',
              ),
              if (validPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: validPoints
                          .map((point) => LatLng(point.latitude, point.longitude))
                          .toList(),
                      strokeWidth: 3,
                      color: AppColors.brandBlue.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              if (validPoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    _buildMarker(
                      context,
                      LatLng(validPoints.first.latitude, validPoints.first.longitude),
                      const Color(0xFF22C55E),
                      'Start',
                    ),
                    if (validPoints.length > 1)
                      _buildMarker(
                        context,
                        LatLng(validPoints.last.latitude, validPoints.last.longitude),
                        const Color(0xFFEF4444),
                        'End',
                      ),
                  ],
                ),
              if (validPoints.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.map_outlined, color: Colors.white70, size: 34),
                      SizedBox(height: 8),
                      Text(
                        'Waiting for tracking data',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (validPoints.isNotEmpty)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  shape: const CircleBorder(),
                  color: AppColors.brandBlue,
                  child: InkWell(
                    onTap: _centerOnLastMarker,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.gps_fixed,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  MapOptions _buildMapOptions(List<TrackingPointModel> validPoints) {
    if (validPoints.isEmpty) {
      return const MapOptions(
        initialCenter: LatLng(16.0, 106.0),
        initialZoom: 5.5,
      );
    }

    final center = LatLng(validPoints.last.latitude, validPoints.last.longitude);
    if (validPoints.length < 2) {
      return MapOptions(
        initialCenter: center,
        initialZoom: 15,
      );
    }

    final latitudes = validPoints.map((point) => point.latitude).toList();
    final longitudes = validPoints.map((point) => point.longitude).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);

    final latSpread = (maxLat - minLat).abs();
    final lngSpread = (maxLng - minLng).abs();

    if (latSpread < 0.00005 && lngSpread < 0.00005) {
      return MapOptions(
        initialCenter: center,
        initialZoom: 15,
      );
    }

    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          validPoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
        ),
        padding: const EdgeInsets.all(28),
      ),
    );
  }

}

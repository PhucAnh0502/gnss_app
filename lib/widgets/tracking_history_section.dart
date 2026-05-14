import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/models/tracking_point_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class TrackingHistorySection extends ConsumerStatefulWidget {
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
  ConsumerState<TrackingHistorySection> createState() => _TrackingHistorySectionState();
}

class _TrackingHistorySectionState extends ConsumerState<TrackingHistorySection> {
  static const _pageSize = 10;
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant TrackingHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first page when data changes
    if (oldWidget.bundle.points.length != widget.bundle.points.length) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPoints = widget.bundle.hasPoints;
    final allPoints = widget.bundle.points.reversed.toList();
    final totalPages = hasPoints ? (allPoints.length / _pageSize).ceil() : 0;
    final pagePoints = hasPoints ? allPoints.skip(_currentPage * _pageSize).take(_pageSize).toList() : <TrackingPointModel>[];

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
                    widget.device == null
                        ? 'Select a device to inspect its recent route.'
                        : '${widget.device!.deviceName} \u2022 ${widget.bundle.pointCount} points',
                    style: const TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                ],
              ),
            ),
            _StatusPill(
              label: widget.device == null ? 'No device' : _statusLabel(widget.device!.status),
              color: _statusColor(widget.device?.status),
            ),
          ],
        ),
        if (widget.showRangeChips) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RangeChip(label: '24h', selected: widget.selectedRangeDays == 1, onTap: () => widget.onRangeSelected(1)),
              _RangeChip(label: '7d', selected: widget.selectedRangeDays == 7, onTap: () => widget.onRangeSelected(7)),
              _RangeChip(label: '30d', selected: widget.selectedRangeDays == 30, onTap: () => widget.onRangeSelected(30)),
              _RangeChip(label: 'All available', selected: false, onTap: () => widget.onRangeSelected(30)),
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
          child: _HistoryMap(points: widget.bundle.points),
        ),
        const SizedBox(height: 16),

        // Recent points header + pagination
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent points',
                style: TextStyle(color: AppColors.textLight, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (hasPoints && totalPages > 1)
              _PaginationControls(
                currentPage: _currentPage,
                totalPages: totalPages,
                onPageChanged: (page) => setState(() => _currentPage = page),
              ),
          ],
        ),
        if (hasPoints)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              '${_currentPage * _pageSize + 1}\u2013${(_currentPage * _pageSize + pagePoints.length).clamp(0, allPoints.length)} of ${allPoints.length}',
              style: const TextStyle(color: AppColors.slate500, fontSize: 11),
            ),
          ),
        if (!hasPoints)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
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
            ),
          ),
        if (hasPoints)
          _PointsList(key: ValueKey('page_$_currentPage'), points: pagePoints),
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

// ===== PAGINATION CONTROLS =====
class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First page
        _PagBtn(
          icon: Icons.first_page_rounded,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(0),
        ),
        // Previous
        _PagBtn(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 4),
        // Page indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${currentPage + 1} / $totalPages',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brandBlueLight, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 4),
        // Next
        _PagBtn(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
        // Last page
        _PagBtn(
          icon: Icons.last_page_rounded,
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(totalPages - 1),
        ),
      ],
    );
  }
}

class _PagBtn extends StatelessWidget {
  const _PagBtn({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.slate300 : AppColors.slate700,
          ),
        ),
      ),
    );
  }
}

// ===== POINTS LIST (isolated widget to avoid element tree issues) =====
class _PointsList extends StatelessWidget {
  const _PointsList({super.key, required this.points});

  final List<TrackingPointModel> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecentPointTile(point: point),
          ),
      ],
    );
  }
}

// ===== RECENT POINT TILE (tappable) =====
class _RecentPointTile extends StatelessWidget {
  const _RecentPointTile({required this.point});

  final TrackingPointModel point;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRawGnssDetail(context, point),
        borderRadius: BorderRadius.circular(18),
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
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate500, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRawGnssDetail(BuildContext context, TrackingPointModel point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RawGnssDetailSheet(point: point),
    );
  }
}

// ===== RAW GNSS DETAIL BOTTOM SHEET =====
class _RawGnssDetailSheet extends StatelessWidget {
  const _RawGnssDetailSheet({required this.point});

  final TrackingPointModel point;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF07111F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate400.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.satellite_alt, color: AppColors.brandBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GNSS Data',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textLight),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${point.dateLabel} at ${point.timeLabel}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Position section
                  _SectionHeader(title: 'Position', icon: Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  _DataRow(label: 'Latitude', value: point.latitude.toStringAsFixed(8)),
                  _DataRow(label: 'Longitude', value: point.longitude.toStringAsFixed(8)),
                  _DataRow(label: 'Altitude', value: '${point.altitude.toStringAsFixed(2)} m'),
                  const SizedBox(height: 16),

                  // Motion section
                  _SectionHeader(title: 'Motion', icon: Icons.speed_outlined),
                  const SizedBox(height: 8),
                  _DataRow(label: 'Speed', value: '${point.speed.toStringAsFixed(2)} km/h'),
                  _DataRow(label: 'Heading', value: '${point.heading.toStringAsFixed(2)}\u00B0'),
                  const SizedBox(height: 16),

                  // Signal Quality section
                  _SectionHeader(title: 'Signal Quality', icon: Icons.signal_cellular_alt),
                  const SizedBox(height: 8),
                  _DataRow(label: 'HDOP', value: point.hdop.toStringAsFixed(3)),
                  _DataRow(label: 'Satellites Used', value: '${point.satellitesUsed}'),
                  _DataRow(label: 'Satellites Count', value: '${point.satellitesCount}'),
                  _DataRow(label: 'Avg C/N0', value: '${point.avgCn0.toStringAsFixed(1)} dB-Hz'),
                  const SizedBox(height: 16),

                  // Metadata section
                  _SectionHeader(title: 'Metadata', icon: Icons.info_outline),
                  const SizedBox(height: 8),
                  _DataRow(label: 'Timestamp (UTC)', value: point.timestamp.toUtc().toIso8601String()),
                  _DataRow(label: 'Timestamp (Local)', value: point.timestamp.toLocal().toString()),
                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandBlueLight),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.brandBlueLight,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.bgSidebar.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate400.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
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

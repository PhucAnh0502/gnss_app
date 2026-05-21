import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/providers/live_position_provider.dart';
import 'package:gnss_app/providers/tracking_history_provider.dart';
import 'package:gnss_app/providers/snapshot_provider.dart';
import 'package:gnss_app/widgets/snapshot_detail_modal.dart';
import 'package:latlong2/latlong.dart';

class LiveDevicesMap extends ConsumerStatefulWidget {
  const LiveDevicesMap({
    super.key,
    required this.devices,
    required this.selectedDeviceId,
  });

  final List<DeviceModel> devices;
  final String selectedDeviceId;

  @override
  ConsumerState<LiveDevicesMap> createState() => _LiveDevicesMapState();
}

class _LiveDevicesMapState extends ConsumerState<LiveDevicesMap> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _centerOnSelectedDevice() async {
    final selectedDevice = widget.devices.firstWhereOrNull(
      (d) => d.id == widget.selectedDeviceId,
    );
    if (selectedDevice == null) return;

    // First try live position
    final livePositions = ref.read(livePositionProvider);
    final livePos = livePositions[selectedDevice.deviceCode];
    if (livePos != null) {
      _mapController.move(livePos.position, 15);
      return;
    }

    // Fallback to history
    try {
      final historyKey = '${selectedDevice.id}|1';
      final history = await ref.read(trackingHistoryProvider(historyKey).future);
      if (history.points.isNotEmpty) {
        final lastPoint = history.points.last;
        if (lastPoint.latitude.isFinite && lastPoint.longitude.isFinite && mounted) {
          _mapController.move(LatLng(lastPoint.latitude, lastPoint.longitude), 15);
        }
      }
    } catch (e) {
      debugPrint('Error getting device location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(16.0, 106.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: defaultCenter,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'gnss_app',
              ),
              // Polyline for selected device (history + live trail)
              _SelectedDevicePolyline(
                deviceId: widget.selectedDeviceId,
                deviceCode: widget.devices
                    .firstWhereOrNull((d) => d.id == widget.selectedDeviceId)
                    ?.deviceCode ?? '',
              ),
              // Device markers (with live position overlay)
              _DeviceMarkers(
                devices: widget.devices,
                selectedDeviceId: widget.selectedDeviceId,
              ),
              // Snapshot markers
              _SnapshotMarkers(
                deviceId: widget.selectedDeviceId,
              ),
            ],
          ),
          // Center button
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
                  onTap: _centerOnSelectedDevice,
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
}

class _SnapshotMarkers extends ConsumerWidget {
  const _SnapshotMarkers({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snapshotProvider);
    final snapshots = state.items.where((item) => item.deviceId == deviceId && item.latitude != null && item.longitude != null).toList();

    if (snapshots.isEmpty) return const SizedBox.shrink();

    final markers = snapshots.map((snapshot) {
      return Marker(
        point: LatLng(snapshot.latitude!, snapshot.longitude!),
        width: 42,
        height: 42,
        child: GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SnapshotDetailModal(snapshot: snapshot),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandBlue,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandBlue.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
          ),
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}

class _SelectedDevicePolyline extends ConsumerWidget {
  const _SelectedDevicePolyline({
    required this.deviceId,
    required this.deviceCode,
  });

  final String deviceId;
  final String deviceCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get history points
    final historyKey = '$deviceId|1';
    final historyAsync = ref.watch(trackingHistoryProvider(historyKey));

    // Get live trail points
    final liveTrails = ref.watch(liveTrailProvider);
    final liveTrail = liveTrails[deviceCode] ?? [];

    // Build combined points list
    final List<LatLng> allPoints = [];

    // Add history points
    if (historyAsync is AsyncData) {
      final bundle = historyAsync.value;
      if (bundle != null) {
        final validHistoryPoints = bundle.points
            .where((p) => p.latitude.isFinite && p.longitude.isFinite)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        allPoints.addAll(validHistoryPoints);
      }
    }

    // Append live trail points
    allPoints.addAll(liveTrail);

    if (allPoints.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: allPoints,
          strokeWidth: 3,
          color: AppColors.brandBlue.withValues(alpha: 0.8),
        ),
      ],
    );
  }
}

class _DeviceMarkers extends ConsumerWidget {
  const _DeviceMarkers({
    required this.devices,
    required this.selectedDeviceId,
  });

  final List<DeviceModel> devices;
  final String selectedDeviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live positions from Socket.IO
    final livePositions = ref.watch(livePositionProvider);
    final markers = <Marker>[];

    for (final device in devices) {
      LatLng? point;

      // Priority 1: Use live position from Socket.IO if available
      final livePos = livePositions[device.deviceCode];
      if (livePos != null) {
        point = livePos.position;
      }

      // Priority 2: Fallback to history data
      if (point == null) {
        final historyKey = '${device.id}|1';
        final historyAsync = ref.watch(trackingHistoryProvider(historyKey));

        if (historyAsync is AsyncData) {
          final bundle = historyAsync.value;
          if (bundle != null && bundle.points.isNotEmpty) {
            final lastPoint = bundle.points.last;
            if (lastPoint.latitude.isFinite && lastPoint.longitude.isFinite) {
              point = LatLng(lastPoint.latitude, lastPoint.longitude);
            }
          }
        }
      }

      // Skip if no position available
      if (point == null) continue;

      final isSelected = device.id == selectedDeviceId;
      final isActive = device.status.toLowerCase() == 'active';
      final hasLiveData = livePositions.containsKey(device.deviceCode);

      Color markerColor;
      if (isSelected) {
        markerColor = AppColors.brandBlue;
      } else if (hasLiveData) {
        // Bright color for devices with live data
        markerColor = const Color(0xFF22C55E); // green for live
      } else if (isActive) {
        markerColor = const Color(0xFF38BDF8);
      } else {
        markerColor = AppColors.slate400;
      }

      final marker = Marker(
        point: point,
        width: isSelected ? 30 : 20,
        height: isSelected ? 30 : 20,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor.withValues(alpha: 0.95),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: markerColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Show a pulsing dot for live devices
          child: hasLiveData
              ? Center(
                  child: Container(
                    width: isSelected ? 10 : 6,
                    height: isSelected ? 10 : 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
      );

      markers.add(marker);
    }

    return MarkerLayer(markers: markers);
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

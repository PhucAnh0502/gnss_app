import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gnss_app/constants/app_colors.dart';
import 'package:gnss_app/models/device_model.dart';
import 'package:gnss_app/providers/tracking_history_provider.dart';
import 'package:latlong2/latlong.dart';

class LiveDevicesMap extends ConsumerStatefulWidget {
  const LiveDevicesMap({
    super.key,
    required this.devices,
    required this.selectedDeviceId,
    required this.onDeviceSelected,
  });

  final List<DeviceModel> devices;
  final String selectedDeviceId;
  final ValueChanged<DeviceModel>? onDeviceSelected;

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

  Future<LatLng?> _getDeviceLocation(String deviceId) async {
    try {
      final historyKey = '$deviceId|1';
      final history = await ref.read(trackingHistoryProvider(historyKey).future);
      if (history.points.isNotEmpty) {
        final lastPoint = history.points.last;
        if (lastPoint.latitude.isFinite && lastPoint.longitude.isFinite) {
          return LatLng(lastPoint.latitude, lastPoint.longitude);
        }
      }
    } catch (e) {
      debugPrint('Error getting device location: $e');
    }
    return null;
  }

  Future<void> _centerOnSelectedDevice() async {
    final selectedDevice = widget.devices.firstWhereOrNull(
      (d) => d.id == widget.selectedDeviceId,
    );
    if (selectedDevice != null) {
      final location = await _getDeviceLocation(selectedDevice.id);
      if (location != null && mounted) {
        _mapController.move(location, 15);
      }
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
              // Polyline for selected device
              _SelectedDevicePolyline(
                deviceId: widget.selectedDeviceId,
              ),
              // Device markers
              _DeviceMarkers(
                devices: widget.devices,
                selectedDeviceId: widget.selectedDeviceId,
                onDeviceSelected: widget.onDeviceSelected,
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

class _SelectedDevicePolyline extends ConsumerWidget {
  const _SelectedDevicePolyline({
    required this.deviceId,
  });

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyKey = '$deviceId|1';
    final historyAsync = ref.watch(trackingHistoryProvider(historyKey));

    if (historyAsync is! AsyncData) {
      return const SizedBox.shrink();
    }

    final bundle = historyAsync.value;
    if (bundle == null) {
      return const SizedBox.shrink();
    }
    final validPoints = bundle.points
        .where((p) => p.latitude.isFinite && p.longitude.isFinite)
        .toList();

    if (validPoints.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: validPoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
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
    required this.onDeviceSelected,
  });

  final List<DeviceModel> devices;
  final String selectedDeviceId;
  final ValueChanged<DeviceModel>? onDeviceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final markers = <Marker>[];

     for (final device in devices) {
       final historyKey = '${device.id}|1';
       final historyAsync = ref.watch(trackingHistoryProvider(historyKey));

       // Only process if data is available
       if (historyAsync is! AsyncData) {
         continue;
       }

       final bundle = historyAsync.value;
       if (bundle == null) {
         continue;
       }
       if (bundle.points.isEmpty) {
         continue;
       }

       final lastPoint = bundle.points.last;
       if (!lastPoint.latitude.isFinite || !lastPoint.longitude.isFinite) {
         continue;
       }

       final isSelected = device.id == selectedDeviceId;
       final point = LatLng(lastPoint.latitude, lastPoint.longitude);
       final isActive = device.status.toLowerCase() == 'active';

       Color markerColor;
       if (isSelected) {
         markerColor = AppColors.brandBlue;
       } else if (isActive) {
         markerColor = const Color(0xFF38BDF8);
       } else {
         markerColor = AppColors.slate400;
       }

       final marker = Marker(
         point: point,
         width: isSelected ? 40 : 32,
         height: isSelected ? 40 : 32,
         child: GestureDetector(
           onTap: () => onDeviceSelected?.call(device),
           child: Container(
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: markerColor.withValues(alpha: 0.95),
               border: Border.all(
                 color: Colors.white.withValues(alpha: 0.8),
                 width: isSelected ? 2 : 1.5,
               ),
               boxShadow: [
                 BoxShadow(
                   color: markerColor.withValues(alpha: 0.4),
                   blurRadius: 12,
                   offset: const Offset(0, 4),
                 ),
               ],
             ),
           ),
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

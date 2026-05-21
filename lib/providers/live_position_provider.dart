import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import '../services/socket_service.dart';
import 'device_provider.dart';

/// Represents a live position update from Socket.IO
class LivePosition {
  final String deviceCode;
  final LatLng position;
  final double speed;
  final double heading;
  final double altitude;
  final int timestamp;

  const LivePosition({
    required this.deviceCode,
    required this.position,
    this.speed = 0,
    this.heading = 0,
    this.altitude = 0,
    this.timestamp = 0,
  });
}

/// Maintains a map of deviceCode → latest LivePosition from Socket.IO.
/// Updates in real-time as devices move.
class LivePositionNotifier extends StateNotifier<Map<String, LivePosition>> {
  LivePositionNotifier(this._socketService) : super({}) {
    _subscribe();
  }

  final SocketService _socketService;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  void _subscribe() {
    _subscription = _socketService.watchAllDeviceUpdates().listen((data) {
      final deviceCode = data['deviceCode'] as String?;
      if (deviceCode == null || deviceCode.isEmpty) return;

      final lat = _toDouble(data['lat']);
      final lng = _toDouble(data['lng']);
      if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;

      final position = LivePosition(
        deviceCode: deviceCode,
        position: LatLng(lat, lng),
        speed: _toDouble(data['sp']) ?? 0,
        heading: _toDouble(data['hd']) ?? 0,
        altitude: _toDouble(data['alt']) ?? 0,
        timestamp: _toInt(data['ts']) ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );

      // Update state with new position for this device
      state = {...state, deviceCode: position};
    });
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that exposes real-time device positions from Socket.IO.
/// Key: deviceCode, Value: LivePosition with latest lat/lng.
final livePositionProvider =
    StateNotifierProvider<LivePositionNotifier, Map<String, LivePosition>>(
  (ref) {
    final socketService = ref.watch(socketServiceProvider);
    return LivePositionNotifier(socketService);
  },
);

/// Maintains a trail of live positions per device (last N points).
class LiveTrailNotifier extends StateNotifier<Map<String, List<LatLng>>> {
  LiveTrailNotifier(this._socketService) : super({}) {
    _subscribe();
  }

  final SocketService _socketService;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  static const int _maxTrailPoints = 60;

  void _subscribe() {
    _subscription = _socketService.watchAllDeviceUpdates().listen((data) {
      final deviceCode = data['deviceCode'] as String?;
      if (deviceCode == null || deviceCode.isEmpty) return;

      final lat = _toDouble(data['lat']);
      final lng = _toDouble(data['lng']);
      if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;

      final point = LatLng(lat, lng);
      final currentTrail = state[deviceCode] ?? [];
      final updatedTrail = [...currentTrail, point];

      // Keep only last N points
      final trimmed = updatedTrail.length > _maxTrailPoints
          ? updatedTrail.sublist(updatedTrail.length - _maxTrailPoints)
          : updatedTrail;

      state = {...state, deviceCode: trimmed};
    });
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider that exposes live trail (list of LatLng) per device.
final liveTrailProvider =
    StateNotifierProvider<LiveTrailNotifier, Map<String, List<LatLng>>>(
  (ref) {
    final socketService = ref.watch(socketServiceProvider);
    return LiveTrailNotifier(socketService);
  },
);

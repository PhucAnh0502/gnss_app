import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tracking_point_model.dart';
import '../services/tracking_service.dart';

final trackingServiceProvider = Provider((ref) => TrackingService());

final trackingHistoryProvider = FutureProvider.family<TrackingHistoryBundle, String>(
  (ref, key) async {
    final parts = key.split('|');
    final deviceId = parts.isNotEmpty ? parts[0] : '';
    final days = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    if (deviceId.isEmpty) {
      throw Exception('Device id is required.');
    }

    final service = ref.watch(trackingServiceProvider);
    final to = DateTime.now().toUtc();
    final from = to.subtract(Duration(days: days));
    return service.getDeviceHistory(deviceId, from: from, to: to);
  },
);

final trackingHistoryRangeProvider = FutureProvider.family<TrackingHistoryBundle, String>(
  (ref, key) async {
    final parts = key.split('|');
    final deviceId = parts.isNotEmpty ? parts[0] : '';
    final fromIso = parts.length > 1 ? parts[1] : '';
    final toIso = parts.length > 2 ? parts[2] : '';

    if (deviceId.isEmpty) {
      throw Exception('Device id is required.');
    }

    final from = DateTime.tryParse(fromIso)?.toUtc();
    final to = DateTime.tryParse(toIso)?.toUtc();
    if (from == null || to == null) {
      throw Exception('Invalid date range.');
    }

    final service = ref.watch(trackingServiceProvider);
    return service.getDeviceHistory(deviceId, from: from, to: to);
  },
);

final latestTrackingProvider = FutureProvider.family<TrackingPointModel?, String>(
  (ref, deviceId) async {
    if (deviceId.isEmpty) {
      return null;
    }
    final service = ref.watch(trackingServiceProvider);
    return service.getLatestDeviceLocation(deviceId);
  },
);

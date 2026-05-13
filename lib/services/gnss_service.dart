import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:raw_gnss_2025/raw_gnss.dart';


class GnssService {
  final RawGnss _rawGnss = RawGnss();

  // Variable to hold the latest GNSS status
  Map<String, dynamic> _latestSnapshot = {
    "tracking": {},
    'raw': {'status': [], 'measurements': [], 'clock': {}},
  };

  StreamSubscription? _posSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _measureSub;

  Future<void> ensureLocationPermission() {
    return _ensureLocationPermission();
  }

  Future<void> startCollection() async {
    await _ensureLocationPermission();
    stopCollection();

    // Thread 1: Location (Geolocator - Fused Location)
    _posSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        intervalDuration: Duration(milliseconds: 500)
      ),
    ).listen((pos) {
      _latestSnapshot['tracking'] = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'sp': (pos.speed * 3.6).roundToDouble(), // Convert m/s to km/h
        'alt': pos.altitude,
        'acc': pos.accuracy,
        'ts': DateTime.now().toIso8601String(),
      };
    }, onError: (_) {});

    //Thread 2 Satellite Status
    _statusSub = _rawGnss.gnssStatusEvents.listen((status) {
      final usedInFix = status.status?.where((s) => s.usedInFix == true).length ?? 0;
      double avgCn0 = 0;
      if(status.status != null && status.status!.isNotEmpty) {
        avgCn0 = status.status!.map((s) => s.cn0DbHz ?? 0).reduce((a,b) => a + b) / status.status!.length;
      }

      _latestSnapshot['tracking']['satCount'] = status.satelliteCount;
      _latestSnapshot['tracking']['satUsed'] = usedInFix;
      _latestSnapshot['tracking']['avgCn0'] = avgCn0.roundToDouble();
      _latestSnapshot['raw']['status'] = status.status?.map((s) => s.toJson()).toList() ?? [];
    }, onError: (_) {});

    //Thread 3: Raw Measurements and Clock
    _measureSub = _rawGnss.gnssMeasurementEvents.listen((measure) {
      _latestSnapshot['raw']['measurements'] = measure.measurements?.map((m) => m.toJson()).toList() ?? [];
      _latestSnapshot['raw']['clock'] = measure.clock?.toJson() ?? {};
    }, onError: (_) {});
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('User denied permissions to access the device\'s location.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Please allow it in app settings.',
      );
    }
  }

  Map<String, dynamic> getCurrentSnapshot() {
    return _latestSnapshot;
  }

  void stopCollection() {
    _posSub?.cancel();
    _statusSub?.cancel();
    _measureSub?.cancel();
    _posSub = null;
    _statusSub = null;
    _measureSub = null;
  }
}
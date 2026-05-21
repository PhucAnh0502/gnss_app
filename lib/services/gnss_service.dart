import 'dart:async';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:raw_gnss_2025/raw_gnss.dart';

/// Configuration for GNSS filtering and smoothing.
class _GnssConfig {
  /// Speed below this threshold (km/h) is treated as stationary.
  static const double speedDeadZone = 2.0;

  /// Speed above this threshold (km/h) means GPS bearing is reliable.
  static const double gpsBearingMinSpeed = 5.0;

  /// Number of recent speed samples to average.
  static const int speedSmoothingWindow = 5;

  /// Number of recent heading samples to average.
  static const int headingSmoothingWindow = 5;

  /// Weight for GPS bearing when blending with compass (0.0 - 1.0).
  /// Higher speed → higher weight for GPS bearing.
  static double gpsBearingWeight(double speedKmh) {
    if (speedKmh >= gpsBearingMinSpeed) return 1.0;
    if (speedKmh <= speedDeadZone) return 0.0;
    // Linear interpolation between dead zone and min speed
    return (speedKmh - speedDeadZone) / (gpsBearingMinSpeed - speedDeadZone);
  }
}

class GnssService {
  final RawGnss _rawGnss = RawGnss();

  // Latest snapshot to be published
  final Map<String, dynamic> _latestSnapshot = {
    "tracking": {},
    'raw': {'status': [], 'measurements': [], 'clock': {}},
  };

  StreamSubscription? _posSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _measureSub;
  StreamSubscription? _compassSub;

  // Compass heading from magnetometer
  double? _compassHeading;

  // Circular buffers for smoothing
  final List<double> _speedBuffer = [];
  final List<double> _headingBuffer = [];

  // Last known valid heading for when device is stationary
  double _lastValidHeading = 0.0;

  Future<void> ensureLocationPermission() {
    return _ensureLocationPermission();
  }

  Future<void> startCollection() async {
    await _ensureLocationPermission();
    stopCollection();

    // Stream 1: Compass (magnetometer heading)
    _startCompassStream();

    // Stream 2: Location (Geolocator - Fused Location)
    _posSub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        intervalDuration: const Duration(seconds: 1),
        distanceFilter: 0,
      ),
    ).listen((pos) {
      final rawSpeedKmh = pos.speed * 3.6; // m/s → km/h
      final rawGpsBearing = pos.heading; // 0-360 from GPS

      // --- Speed processing ---
      final smoothedSpeed = _processSpeed(rawSpeedKmh);

      // --- Heading processing (sensor fusion) ---
      final fusedHeading = _processHeading(
        gpsBearing: rawGpsBearing,
        speedKmh: smoothedSpeed,
      );

      _latestSnapshot['tracking'] = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'sp': double.parse(smoothedSpeed.toStringAsFixed(1)),
        'alt': pos.altitude,
        'hd': double.parse(fusedHeading.toStringAsFixed(1)),
        'acc': pos.accuracy,
        'hdop': pos.accuracy / 5.0,
        'ts': DateTime.now().toIso8601String(),
        // Raw values for debugging
        'rawSpeed': double.parse(rawSpeedKmh.toStringAsFixed(2)),
        'rawGpsBearing': double.parse(rawGpsBearing.toStringAsFixed(1)),
        'compassHeading': _compassHeading != null
            ? double.parse(_compassHeading!.toStringAsFixed(1))
            : null,
        'headingSource': _getHeadingSource(smoothedSpeed),
      };
    }, onError: (_) {});

    // Stream 3: Satellite Status
    _statusSub = _rawGnss.gnssStatusEvents.listen((status) {
      final usedInFix =
          status.status?.where((s) => s.usedInFix == true).length ?? 0;
      double avgCn0 = 0;
      if (status.status != null && status.status!.isNotEmpty) {
        avgCn0 = status.status!
                .map((s) => s.cn0DbHz ?? 0)
                .reduce((a, b) => a + b) /
            status.status!.length;
      }

      _latestSnapshot['tracking']['satCount'] = status.satelliteCount;
      _latestSnapshot['tracking']['satUsed'] = usedInFix;
      _latestSnapshot['tracking']['avgCn0'] = avgCn0.roundToDouble();
      _latestSnapshot['raw']['status'] =
          status.status?.map((s) => s.toJson()).toList() ?? [];
    }, onError: (_) {});

    // Stream 4: Raw Measurements and Clock
    _measureSub = _rawGnss.gnssMeasurementEvents.listen((measure) {
      _latestSnapshot['raw']['measurements'] =
          measure.measurements?.map((m) => m.toJson()).toList() ?? [];
      _latestSnapshot['raw']['clock'] = measure.clock?.toJson() ?? {};
    }, onError: (_) {});
  }

  /// Start compass stream for magnetometer-based heading.
  void _startCompassStream() {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && event.heading!.isFinite) {
        // Normalize to 0-360
        _compassHeading = (event.heading! + 360) % 360;
      }
    }, onError: (_) {});
  }

  /// Process speed with dead zone and moving average smoothing.
  double _processSpeed(double rawSpeedKmh) {
    // Dead zone: treat very low speeds as 0
    final effectiveSpeed =
        rawSpeedKmh < _GnssConfig.speedDeadZone ? 0.0 : rawSpeedKmh;

    // Add to buffer
    _speedBuffer.add(effectiveSpeed);
    if (_speedBuffer.length > _GnssConfig.speedSmoothingWindow) {
      _speedBuffer.removeAt(0);
    }

    // Moving average
    if (_speedBuffer.isEmpty) return 0.0;
    final sum = _speedBuffer.reduce((a, b) => a + b);
    return sum / _speedBuffer.length;
  }

  /// Process heading with sensor fusion (GPS bearing + compass).
  ///
  /// Strategy:
  /// - Speed > 5 km/h: Use GPS bearing (most accurate when moving)
  /// - Speed < 2 km/h: Use compass heading (GPS bearing unreliable when slow)
  /// - Speed 2-5 km/h: Blend GPS bearing and compass with linear weight
  double _processHeading({
    required double gpsBearing,
    required double speedKmh,
  }) {
    final gpsWeight = _GnssConfig.gpsBearingWeight(speedKmh);
    double heading;

    if (gpsWeight >= 1.0) {
      // High speed: trust GPS bearing completely
      heading = gpsBearing;
    } else if (gpsWeight <= 0.0) {
      // Stationary/very slow: use compass or last valid heading
      heading = _compassHeading ?? _lastValidHeading;
    } else {
      // Blend: weighted circular average of GPS bearing and compass
      final compass = _compassHeading ?? _lastValidHeading;
      heading = _circularWeightedAverage(gpsBearing, compass, gpsWeight);
    }

    // Normalize to 0-360
    heading = (heading + 360) % 360;

    // Smooth heading with circular moving average
    _headingBuffer.add(heading);
    if (_headingBuffer.length > _GnssConfig.headingSmoothingWindow) {
      _headingBuffer.removeAt(0);
    }

    final smoothed = _circularMean(_headingBuffer);

    // Update last valid heading when we have confidence
    if (speedKmh > _GnssConfig.speedDeadZone || _compassHeading != null) {
      _lastValidHeading = smoothed;
    }

    return smoothed;
  }

  /// Circular weighted average of two angles (in degrees).
  double _circularWeightedAverage(
      double angle1, double angle2, double weight1) {
    final weight2 = 1.0 - weight1;
    final rad1 = angle1 * pi / 180;
    final rad2 = angle2 * pi / 180;

    final x = weight1 * cos(rad1) + weight2 * cos(rad2);
    final y = weight1 * sin(rad1) + weight2 * sin(rad2);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  /// Circular mean of a list of angles (in degrees).
  /// Handles the 0°/360° wraparound correctly.
  double _circularMean(List<double> angles) {
    if (angles.isEmpty) return 0.0;

    double sumX = 0;
    double sumY = 0;

    for (final angle in angles) {
      final rad = angle * pi / 180;
      sumX += cos(rad);
      sumY += sin(rad);
    }

    return (atan2(sumY / angles.length, sumX / angles.length) * 180 / pi +
            360) %
        360;
  }

  /// Get a human-readable heading source label for debugging.
  String _getHeadingSource(double speedKmh) {
    final gpsWeight = _GnssConfig.gpsBearingWeight(speedKmh);
    if (gpsWeight >= 1.0) return 'gps';
    if (gpsWeight <= 0.0) return _compassHeading != null ? 'compass' : 'last';
    return 'fused(gps:${(gpsWeight * 100).round()}%)';
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
      throw Exception(
          'User denied permissions to access the device\'s location.');
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
    _compassSub?.cancel();
    _posSub = null;
    _statusSub = null;
    _measureSub = null;
    _compassSub = null;
    _speedBuffer.clear();
    _headingBuffer.clear();
  }
}

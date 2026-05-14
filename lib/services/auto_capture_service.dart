import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gnss_service.dart';
import 'snapshot_service.dart';

/// SharedPreferences keys for auto-capture configuration.
class AutoCaptureKeys {
  AutoCaptureKeys._();
  static const enabled = 'auto_capture_enabled';
  static const mode = 'auto_capture_mode'; // 'timer' | 'distance'
  static const intervalSeconds = 'auto_capture_interval';
  static const distanceMeters = 'auto_capture_distance';
  static const quality = 'auto_capture_quality'; // 'low' | 'medium' | 'high'
  static const deviceId = 'auto_capture_device_id';
}

enum AutoCaptureMode { timer, distance }

/// Handles automatic photo capture with GNSS metadata.
/// Designed to run inside the background service isolate.
class AutoCaptureService {
  AutoCaptureService({
    required this.gnssService,
    required this.deviceId,
    this.mode = AutoCaptureMode.timer,
    this.intervalSeconds = 60,
    this.distanceMeters = 100,
    this.quality = ResolutionPreset.medium,
  });

  final GnssService gnssService;
  final String deviceId;
  final AutoCaptureMode mode;
  final int intervalSeconds;
  final double distanceMeters;
  final ResolutionPreset quality;

  final SnapshotService _snapshotService = SnapshotService();

  Timer? _timer;
  StreamSubscription? _distanceSub;
  double? _lastLat;
  double? _lastLng;
  bool _isCapturing = false;

  /// Start auto-capture based on configured mode.
  void start() {
    stop();
    print('[AutoCapture] Starting... mode=$mode, interval=${intervalSeconds}s, distance=${distanceMeters}m, deviceId=$deviceId');

    if (mode == AutoCaptureMode.timer) {
      _startTimerMode();
    } else {
      _startDistanceMode();
    }
  }

  /// Stop auto-capture.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _distanceSub?.cancel();
    _distanceSub = null;
    print('[AutoCapture] Stopped');
  }

  void _startTimerMode() {
    // Capture immediately on start, then periodically
    _captureIfReady();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      _captureIfReady();
    });
  }

  void _startDistanceMode() {
    // Check distance every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final snapshot = gnssService.getCurrentSnapshot();
      final tracking = snapshot['tracking'];
      if (tracking is! Map || tracking['lat'] == null || tracking['lng'] == null) return;

      final lat = (tracking['lat'] as num).toDouble();
      final lng = (tracking['lng'] as num).toDouble();

      if (_lastLat == null || _lastLng == null) {
        _lastLat = lat;
        _lastLng = lng;
        return;
      }

      final dist = _haversineDistance(_lastLat!, _lastLng!, lat, lng);
      if (dist >= distanceMeters) {
        _lastLat = lat;
        _lastLng = lng;
        _captureIfReady();
      }
    });
  }

  Future<void> _captureIfReady() async {
    if (_isCapturing) return;

    final snapshot = gnssService.getCurrentSnapshot();
    final tracking = snapshot['tracking'];
    if (tracking is! Map || tracking['lat'] == null || tracking['lng'] == null) {
      print('[AutoCapture] Skipped: no GPS fix yet (lat/lng is null)');
      return;
    }

    print('[AutoCapture] Triggering capture... lat=${tracking['lat']}, lng=${tracking['lng']}');
    _isCapturing = true;
    try {
      await _captureAndUpload(Map<String, dynamic>.from(tracking));
    } catch (e) {
      print('[AutoCapture] Error during capture/upload: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _captureAndUpload(Map<String, dynamic> tracking) async {
    // 1. Take photo
    print('[AutoCapture] Taking photo...');
    final photoFile = await _takePhoto();
    if (photoFile == null) {
      print('[AutoCapture] FAILED: Could not take photo');
      return;
    }
    print('[AutoCapture] Photo captured: ${photoFile.path} (${await photoFile.length()} bytes)');

    try {
      // 2. Build metadata
      final metadata = <String, dynamic>{
        'deviceId': deviceId,
        'captureMode': 'auto',
        'latitude': tracking['lat'],
        'longitude': tracking['lng'],
        'altitude': tracking['alt'] ?? 0,
        'speed': tracking['sp'] ?? 0,
        'heading': tracking['hd'] ?? 0,
        'hdop': tracking['hdop'] ?? 0,
        'satellites_count': tracking['satCount'] ?? 0,
        'satellites_used': tracking['satUsed'] ?? 0,
        'avg_cn0': tracking['avgCn0'] ?? 0,
      };

      // 3. Init snapshot on server
      print('[AutoCapture] Initializing snapshot on server...');
      final initResult = await _snapshotService.initSnapshot(metadata);
      final data = initResult['data'];
      final snapshotId = data is Map ? data['id']?.toString() : initResult['snapshotId']?.toString();

      if (snapshotId == null || snapshotId.isEmpty) {
        print('[AutoCapture] FAILED: Server did not return snapshot ID. Response: $initResult');
        return;
      }
      print('[AutoCapture] Snapshot initialized: $snapshotId');

      // 4. Upload photo
      print('[AutoCapture] Uploading photo...');
      await _snapshotService.uploadFile(snapshotId, photoFile);
      print('[AutoCapture] SUCCESS: Snapshot $snapshotId uploaded!');
    } finally {
      // 5. Cleanup temp file
      if (await photoFile.exists()) {
        await photoFile.delete();
        print('[AutoCapture] Temp file cleaned up');
      }
    }
  }

  Future<File?> _takePhoto() async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('[AutoCapture] Cannot get cameras: $e');
      return null;
    }

    if (cameras.isEmpty) {
      print('[AutoCapture] No cameras available');
      return null;
    }

    // Prefer back camera
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(camera, quality, enableAudio: false);

    try {
      await controller.initialize();
      // Small delay for auto-exposure to settle
      await Future.delayed(const Duration(milliseconds: 500));
      final xFile = await controller.takePicture();
      await controller.dispose();

      // Move to app temp directory with unique name
      final tempDir = await getTemporaryDirectory();
      final fileName = 'auto_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = '${tempDir.path}/$fileName';
      final destFile = await File(xFile.path).copy(destPath);

      // Delete original
      try {
        await File(xFile.path).delete();
      } catch (_) {}

      return destFile;
    } catch (e) {
      print('[AutoCapture] Failed to take photo: $e');
      try {
        await controller.dispose();
      } catch (_) {}
      return null;
    }
  }

  /// Haversine distance in meters between two lat/lng points.
  static double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Load config from SharedPreferences and create service instance.
  static Future<AutoCaptureService?> fromPrefs({
    required GnssService gnssService,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AutoCaptureKeys.enabled) ?? false;
    if (!enabled) return null;

    final deviceId = prefs.getString(AutoCaptureKeys.deviceId)?.trim();
    if (deviceId == null || deviceId.isEmpty) return null;

    final modeStr = prefs.getString(AutoCaptureKeys.mode) ?? 'timer';
    final mode = modeStr == 'distance' ? AutoCaptureMode.distance : AutoCaptureMode.timer;
    final interval = prefs.getInt(AutoCaptureKeys.intervalSeconds) ?? 60;
    final distance = prefs.getDouble(AutoCaptureKeys.distanceMeters) ?? 100;
    final qualityStr = prefs.getString(AutoCaptureKeys.quality) ?? 'medium';

    ResolutionPreset quality;
    switch (qualityStr) {
      case 'low':
        quality = ResolutionPreset.low;
        break;
      case 'high':
        quality = ResolutionPreset.high;
        break;
      default:
        quality = ResolutionPreset.medium;
    }

    return AutoCaptureService(
      gnssService: gnssService,
      deviceId: deviceId,
      mode: mode,
      intervalSeconds: interval,
      distanceMeters: distance,
      quality: quality,
    );
  }
}

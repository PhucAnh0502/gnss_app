import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_capture_service.dart';
import 'gnss_service.dart';
import 'snapshot_service.dart';

/// Runs auto-capture in the main isolate (foreground).
/// Camera plugins require main isolate platform channels.
/// This service should be started/stopped from the UI layer.
class AutoCaptureForegroundService {
  AutoCaptureForegroundService._();

  static AutoCaptureForegroundService? _instance;
  static AutoCaptureForegroundService get instance {
    _instance ??= AutoCaptureForegroundService._();
    return _instance!;
  }

  final SnapshotService _snapshotService = SnapshotService();
  GnssService? _gnssService;
  Timer? _timer;
  bool _isCapturing = false;
  bool _isRunning = false;
  String? _deviceId;
  AutoCaptureMode _mode = AutoCaptureMode.timer;
  int _intervalSeconds = 60;
  double _distanceMeters = 100;
  ResolutionPreset _quality = ResolutionPreset.medium;
  double? _lastLat;
  double? _lastLng;

  bool get isRunning => _isRunning;

  /// Start auto-capture with the given GNSS service (must be already collecting).
  Future<void> start(GnssService gnssService) async {
    if (_isRunning) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AutoCaptureKeys.enabled) ?? false;
    if (!enabled) {
      print('[AutoCapture-FG] Not enabled, skipping');
      return;
    }

    _deviceId = prefs.getString(AutoCaptureKeys.deviceId)?.trim();
    if (_deviceId == null || _deviceId!.isEmpty) {
      print('[AutoCapture-FG] No deviceId configured, skipping');
      return;
    }

    final modeStr = prefs.getString(AutoCaptureKeys.mode) ?? 'timer';
    _mode = modeStr == 'distance' ? AutoCaptureMode.distance : AutoCaptureMode.timer;
    _intervalSeconds = prefs.getInt(AutoCaptureKeys.intervalSeconds) ?? 60;
    _distanceMeters = prefs.getDouble(AutoCaptureKeys.distanceMeters) ?? 100;
    final qualityStr = prefs.getString(AutoCaptureKeys.quality) ?? 'medium';
    _quality = qualityStr == 'low' ? ResolutionPreset.low : qualityStr == 'high' ? ResolutionPreset.high : ResolutionPreset.medium;

    _gnssService = gnssService;
    _isRunning = true;
    _lastLat = null;
    _lastLng = null;

    print('[AutoCapture-FG] Starting... mode=$_mode, interval=${_intervalSeconds}s, distance=${_distanceMeters}m, device=$_deviceId');

    if (_mode == AutoCaptureMode.timer) {
      _startTimerMode();
    } else {
      _startDistanceMode();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _gnssService = null;
    print('[AutoCapture-FG] Stopped');
  }

  void _startTimerMode() {
    // First capture after a short delay
    Future.delayed(const Duration(seconds: 5), () {
      if (_isRunning) _captureIfReady();
    });
    _timer = Timer.periodic(Duration(seconds: _intervalSeconds), (_) {
      if (_isRunning) _captureIfReady();
    });
  }

  void _startDistanceMode() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isRunning || _gnssService == null) return;

      final snapshot = _gnssService!.getCurrentSnapshot();
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
      if (dist >= _distanceMeters) {
        _lastLat = lat;
        _lastLng = lng;
        _captureIfReady();
      }
    });
  }

  Future<void> _captureIfReady() async {
    if (_isCapturing || _gnssService == null) return;

    final snapshot = _gnssService!.getCurrentSnapshot();
    final tracking = snapshot['tracking'];
    if (tracking is! Map || tracking['lat'] == null || tracking['lng'] == null) {
      print('[AutoCapture-FG] Skipped: no GPS fix');
      return;
    }

    print('[AutoCapture-FG] Triggering capture... lat=${tracking['lat']}, lng=${tracking['lng']}');
    _isCapturing = true;
    try {
      await _captureAndUpload(Map<String, dynamic>.from(tracking));
    } catch (e) {
      print('[AutoCapture-FG] Error: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _captureAndUpload(Map<String, dynamic> tracking) async {
    print('[AutoCapture-FG] Taking photo...');
    final photoFile = await _takePhoto();
    if (photoFile == null) {
      print('[AutoCapture-FG] FAILED: Could not take photo');
      return;
    }
    print('[AutoCapture-FG] Photo captured: ${photoFile.path} (${await photoFile.length()} bytes)');

    try {
      final metadata = <String, dynamic>{
        'deviceId': _deviceId,
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

      print('[AutoCapture-FG] Initializing snapshot on server...');
      final initResult = await _snapshotService.initSnapshot(metadata);
      final data = initResult['data'];
      final snapshotId = data is Map ? data['id']?.toString() : initResult['snapshotId']?.toString();

      if (snapshotId == null || snapshotId.isEmpty) {
        print('[AutoCapture-FG] FAILED: No snapshot ID returned. Response: $initResult');
        return;
      }
      print('[AutoCapture-FG] Snapshot initialized: $snapshotId');

      print('[AutoCapture-FG] Uploading photo...');
      await _snapshotService.uploadFile(snapshotId, photoFile);
      print('[AutoCapture-FG] SUCCESS: Snapshot $snapshotId uploaded!');
    } finally {
      if (await photoFile.exists()) {
        await photoFile.delete();
      }
    }
  }

  Future<File?> _takePhoto() async {
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('[AutoCapture-FG] Cannot get cameras: $e');
      return null;
    }

    if (cameras.isEmpty) {
      print('[AutoCapture-FG] No cameras available');
      return null;
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(camera, _quality, enableAudio: false);

    try {
      await controller.initialize();
      await Future.delayed(const Duration(milliseconds: 800));
      final xFile = await controller.takePicture();
      await controller.dispose();

      final tempDir = await getTemporaryDirectory();
      final fileName = 'auto_capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = '${tempDir.path}/$fileName';
      final destFile = await File(xFile.path).copy(destPath);

      try { await File(xFile.path).delete(); } catch (_) {}
      return destFile;
    } catch (e) {
      print('[AutoCapture-FG] Failed to take photo: $e');
      try { await controller.dispose(); } catch (_) {}
      return null;
    }
  }

  static double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}

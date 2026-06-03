import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auto_capture_service.dart';
import '../services/auto_capture_foreground_service.dart';
import '../services/gnss_service.dart';

class AutoCaptureState {
  const AutoCaptureState({
    this.enabled = false,
    this.mode = AutoCaptureMode.timer,
    this.intervalSeconds = 60,
    this.distanceMeters = 100,
    this.quality = 'medium',
    this.deviceId,
    this.isLoading = false,
  });

  final bool enabled;
  final AutoCaptureMode mode;
  final int intervalSeconds;
  final double distanceMeters;
  final String quality;
  final String? deviceId;
  final bool isLoading;

  AutoCaptureState copyWith({
    bool? enabled,
    AutoCaptureMode? mode,
    int? intervalSeconds,
    double? distanceMeters,
    String? quality,
    String? deviceId,
    bool? isLoading,
  }) {
    return AutoCaptureState(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      quality: quality ?? this.quality,
      deviceId: deviceId ?? this.deviceId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AutoCaptureNotifier extends StateNotifier<AutoCaptureState> {
  AutoCaptureNotifier() : super(const AutoCaptureState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();

    // Auto-resolve device ID from physical device
    String? deviceId = prefs.getString(AutoCaptureKeys.deviceId)?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await _resolveDeviceId();
      if (deviceId != null && deviceId.isNotEmpty) {
        await prefs.setString(AutoCaptureKeys.deviceId, deviceId);
      }
    }

    state = AutoCaptureState(
      enabled: prefs.getBool(AutoCaptureKeys.enabled) ?? false,
      mode: (prefs.getString(AutoCaptureKeys.mode) ?? 'timer') == 'distance'
          ? AutoCaptureMode.distance
          : AutoCaptureMode.timer,
      intervalSeconds: prefs.getInt(AutoCaptureKeys.intervalSeconds) ?? 60,
      distanceMeters: prefs.getDouble(AutoCaptureKeys.distanceMeters) ?? 100,
      quality: prefs.getString(AutoCaptureKeys.quality) ?? 'medium',
      deviceId: deviceId,
      isLoading: false,
    );
  }

  /// Resolve device ID from Android device info or SharedPreferences tracking_device_code.
  Future<String?> _resolveDeviceId() async {
    // Try tracking_device_code first (set by tracking provider)
    final prefs = await SharedPreferences.getInstance();
    final trackingDeviceCode = prefs.getString('tracking_device_code')?.trim();
    if (trackingDeviceCode != null && trackingDeviceCode.isNotEmpty) {
      return trackingDeviceCode;
    }

    // Fallback: resolve from Android device ID
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id.trim();
      } catch (_) {}
    }
    return null;
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AutoCaptureKeys.enabled, value);
    _restartAutoCaptureIfTracking();
  }

  Future<void> setMode(AutoCaptureMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AutoCaptureKeys.mode, mode == AutoCaptureMode.distance ? 'distance' : 'timer');
    _restartAutoCaptureIfTracking();
  }

  Future<void> setInterval(int seconds) async {
    state = state.copyWith(intervalSeconds: seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AutoCaptureKeys.intervalSeconds, seconds);
    _restartAutoCaptureIfTracking();
  }

  Future<void> setDistance(double meters) async {
    state = state.copyWith(distanceMeters: meters);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AutoCaptureKeys.distanceMeters, meters);
    _restartAutoCaptureIfTracking();
  }

  Future<void> setQuality(String quality) async {
    state = state.copyWith(quality: quality);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AutoCaptureKeys.quality, quality);
    _restartAutoCaptureIfTracking();
  }

  Future<void> setDeviceId(String? deviceId) async {
    state = state.copyWith(deviceId: deviceId);
    final prefs = await SharedPreferences.getInstance();
    if (deviceId != null) {
      await prefs.setString(AutoCaptureKeys.deviceId, deviceId);
    } else {
      await prefs.remove(AutoCaptureKeys.deviceId);
    }
  }

  /// Restart auto-capture service if tracking is currently active.
  /// This allows settings changes to take effect immediately without
  /// requiring the user to manually restart tracking.
  void _restartAutoCaptureIfTracking() {
    final service = AutoCaptureForegroundService.instance;
    if (!service.isRunning) return;

    // Stop current auto-capture
    service.stop();

    // If still enabled, restart with new settings
    if (state.enabled) {
      final gnssService = GnssService();
      service.start(gnssService);
    }
  }
}

final autoCaptureProvider = StateNotifierProvider<AutoCaptureNotifier, AutoCaptureState>((ref) {
  return AutoCaptureNotifier();
});

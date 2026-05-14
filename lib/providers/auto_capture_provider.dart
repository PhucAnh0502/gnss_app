import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auto_capture_service.dart';

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
    state = AutoCaptureState(
      enabled: prefs.getBool(AutoCaptureKeys.enabled) ?? false,
      mode: (prefs.getString(AutoCaptureKeys.mode) ?? 'timer') == 'distance'
          ? AutoCaptureMode.distance
          : AutoCaptureMode.timer,
      intervalSeconds: prefs.getInt(AutoCaptureKeys.intervalSeconds) ?? 60,
      distanceMeters: prefs.getDouble(AutoCaptureKeys.distanceMeters) ?? 100,
      quality: prefs.getString(AutoCaptureKeys.quality) ?? 'medium',
      deviceId: prefs.getString(AutoCaptureKeys.deviceId),
      isLoading: false,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AutoCaptureKeys.enabled, value);
  }

  Future<void> setMode(AutoCaptureMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AutoCaptureKeys.mode, mode == AutoCaptureMode.distance ? 'distance' : 'timer');
  }

  Future<void> setInterval(int seconds) async {
    state = state.copyWith(intervalSeconds: seconds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AutoCaptureKeys.intervalSeconds, seconds);
  }

  Future<void> setDistance(double meters) async {
    state = state.copyWith(distanceMeters: meters);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AutoCaptureKeys.distanceMeters, meters);
  }

  Future<void> setQuality(String quality) async {
    state = state.copyWith(quality: quality);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AutoCaptureKeys.quality, quality);
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
}

final autoCaptureProvider = StateNotifierProvider<AutoCaptureNotifier, AutoCaptureState>((ref) {
  return AutoCaptureNotifier();
});

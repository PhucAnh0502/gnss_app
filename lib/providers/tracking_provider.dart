import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auto_capture_foreground_service.dart';
import '../services/gnss_service.dart';
import '../services/tracking_background_service.dart';

const _trackingEnabledKey = 'tracking_enabled';
const _trackingDeviceCodeKey = 'tracking_device_code';

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  final notifier = TrackingNotifier();
  notifier.bootstrap();
  return notifier;
});

class TrackingState {
  const TrackingState({
    this.isTracking = false,
    this.isMqttConnected = false,
    this.isMqttConnecting = false,
    this.isBusy = false,
    this.deviceCode,
    this.errorMessage,
  });

  final bool isTracking;
  final bool isMqttConnected;
  final bool isMqttConnecting;
  final bool isBusy;
  final String? deviceCode;
  final String? errorMessage;

  TrackingState copyWith({
    bool? isTracking,
    bool? isMqttConnected,
    bool? isMqttConnecting,
    bool? isBusy,
    String? deviceCode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isMqttConnected: isMqttConnected ?? this.isMqttConnected,
      isMqttConnecting: isMqttConnecting ?? this.isMqttConnecting,
      isBusy: isBusy ?? this.isBusy,
      deviceCode: deviceCode ?? this.deviceCode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  TrackingNotifier() : super(const TrackingState());

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_trackingEnabledKey) ?? false;
      final storedDeviceCode = prefs.getString(_trackingDeviceCodeKey)?.trim();
      final resolvedDeviceCode = storedDeviceCode?.isNotEmpty == true
          ? storedDeviceCode
          : await _resolveAndroidDeviceCode();

      state = state.copyWith(
        isTracking: isEnabled,
        deviceCode: resolvedDeviceCode?.isNotEmpty == true
            ? resolvedDeviceCode
            : null,
        clearError: true,
      );

      if (isEnabled) {
        await _startBackgroundTracking(deviceCode: resolvedDeviceCode);
        // Start auto-capture in foreground
        _startAutoCapture();
      } else {
        AutoCaptureForegroundService.instance.stop();
        await TrackingBackgroundService.stop();
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> setTrackingEnabled(bool enabled) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      if (enabled) {
        final notificationPermission = await Permission.notification.request();
        if (!notificationPermission.isGranted) {
          throw Exception('Notification permission is required to keep tracking running in background.');
        }

        // Request camera permission for auto-capture
        final cameraPermission = await Permission.camera.request();
        if (!cameraPermission.isGranted) {
          print('[Tracking] Camera permission denied — auto-capture will not work');
        }

        final deviceCode = await _resolveAndroidDeviceCode();
        if (deviceCode == null || deviceCode.isEmpty) {
          throw Exception('Không thể lấy device code của thiết bị Android này.');
        }

        await _startBackgroundTracking(deviceCode: deviceCode);
        // Start auto-capture in foreground (camera needs main isolate)
        _startAutoCapture();
        return true;
      }

      AutoCaptureForegroundService.instance.stop();
      await TrackingBackgroundService.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_trackingEnabledKey, false);

      state = state.copyWith(
        isTracking: false,
        isBusy: false,
        isMqttConnected: false,
        isMqttConnecting: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      await TrackingBackgroundService.stop();
      state = state.copyWith(
        isTracking: false,
        isBusy: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> _startBackgroundTracking({String? deviceCode}) async {
    final resolvedDeviceCode =
        deviceCode ?? await _resolveAndroidDeviceCode() ?? '';

    if (resolvedDeviceCode.isEmpty) {
      throw Exception('Không thể khởi tạo tracking khi chưa có device code.');
    }

    final gnssService = GnssService();
    await gnssService.ensureLocationPermission();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, true);
    await prefs.setString(_trackingDeviceCodeKey, resolvedDeviceCode);

    state = state.copyWith(
      isTracking: true,
      isMqttConnecting: true,
      isMqttConnected: false,
      deviceCode: resolvedDeviceCode,
      clearError: true,
    );

    await TrackingBackgroundService.initialize();
    await TrackingBackgroundService.start(deviceCode: resolvedDeviceCode);

    state = state.copyWith(
      isTracking: true,
      isBusy: false,
      isMqttConnecting: false,
      isMqttConnected: true,
      deviceCode: resolvedDeviceCode,
      clearError: true,
    );
  }

  Future<String?> _resolveAndroidDeviceCode() async {
    if (!_isAndroid) {
      return null;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.id.trim();
    } catch (_) {
      return null;
    }
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _startAutoCapture() {
    // Ensure auto-capture has the correct device ID (use tracking device code)
    _syncAutoCaptureDeviceId().then((_) {
      // GnssService needs to be running for auto-capture to read position
      final gnssService = GnssService();
      // Start collection (may already be running in background, but safe to call)
      gnssService.startCollection().then((_) {
        AutoCaptureForegroundService.instance.start(gnssService);
      }).catchError((e) {
        print('[Tracking] Cannot start auto-capture GNSS: $e');
      });
    });
  }

  /// Sync the auto-capture device ID with the tracking device code.
  Future<void> _syncAutoCaptureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final trackingDeviceCode = prefs.getString(_trackingDeviceCodeKey)?.trim();
    if (trackingDeviceCode != null && trackingDeviceCode.isNotEmpty) {
      final currentAutoCaptureDeviceId = prefs.getString('auto_capture_device_id')?.trim();
      if (currentAutoCaptureDeviceId != trackingDeviceCode) {
        await prefs.setString('auto_capture_device_id', trackingDeviceCode);
        print('[Tracking] Synced auto-capture device ID to: $trackingDeviceCode');
      }
    }
  }
}

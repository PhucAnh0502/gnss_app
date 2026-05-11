import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:gnss_app/constants/app_constants.dart';
import 'package:gnss_app/services/gnss_service.dart';
import 'package:gnss_app/services/mqtt_service.dart';

final gnssServiceProvider = Provider<GnssService>((ref) => GnssService());
final mqttServiceProvider = Provider<MqttService>((ref) => MqttService());

class TrackingState {
  final bool isTracking;
  final bool isMqttConnecting;
  final bool isMqttConnected;
  final String? deviceCode;
  final Map<String, dynamic> snapshot;
  final List<String> logs;
  final String? errorMessage;

  const TrackingState({
    this.isTracking = false,
    this.isMqttConnecting = false,
    this.isMqttConnected = false,
    this.deviceCode,
    this.snapshot = const {
      'tracking': <String, dynamic>{},
      'raw': {
        'status': <dynamic>[],
        'measurements': <dynamic>[],
        'clock': <String, dynamic>{},
      },
    },
    this.logs = const [],
    this.errorMessage,
  });

  TrackingState copyWith({
    bool? isTracking,
    bool? isMqttConnecting,
    bool? isMqttConnected,
    String? deviceCode,
    Map<String, dynamic>? snapshot,
    List<String>? logs,
    String? errorMessage,
    bool clearError = false,
    bool clearDeviceCode = false,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isMqttConnecting: isMqttConnecting ?? this.isMqttConnecting,
      isMqttConnected: isMqttConnected ?? this.isMqttConnected,
      deviceCode: clearDeviceCode ? null : (deviceCode ?? this.deviceCode),
      snapshot: snapshot ?? this.snapshot,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  final GnssService _gnssService;
  final MqttService _mqttService;
  Timer? _refreshTimer;
  Timer? _publishTimer;

  TrackingNotifier(this._gnssService, this._mqttService)
      : super(const TrackingState());

  Future<void> startTracking({
    String? deviceCode,
  }) async {
    await stopTracking();

    final resolvedDeviceCode = deviceCode?.trim() ?? '';

    if (resolvedDeviceCode.isEmpty) {
      state = state.copyWith(errorMessage: 'Device code is required.');
      _addLog('Cannot start tracking: device code is empty.');
      return;
    }

    state = state.copyWith(
      isTracking: true,
      isMqttConnecting: true,
      isMqttConnected: false,
      deviceCode: resolvedDeviceCode,
      clearError: true,
    );

    try {
      await _gnssService.startCollection();
    } catch (error) {
      state = state.copyWith(
        isTracking: false,
        isMqttConnecting: false,
        isMqttConnected: false,
        clearDeviceCode: true,
        errorMessage: error.toString(),
      );
      _addLog('GNSS start failed: $error');
      return;
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshSnapshot();
    });

    try {
      final connected = await _mqttService.connect(resolvedDeviceCode);
      state = state.copyWith(
        isMqttConnecting: false,
        isMqttConnected: connected,
      );
      if (!connected) {
        _addLog('MQTT connection failed.');
        return;
      }
    } catch (error) {
      state = state.copyWith(
        isMqttConnecting: false,
        isMqttConnected: false,
        errorMessage: error.toString(),
      );
      _addLog('MQTT connect error: $error');
      return;
    }

    _publishTimer?.cancel();
    _publishTimer = Timer.periodic(
      Duration(seconds: AppConstants.sendIntervalSeconds),
      (_) {
        _publishTelemetry();
      },
    );

    _addLog('Tracking started for deviceCode=$resolvedDeviceCode');
  }

  Future<void> stopTracking() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _publishTimer?.cancel();
    _publishTimer = null;
    _gnssService.stopCollection();
    _mqttService.disconnect();
    state = state.copyWith(
      isTracking: false,
      isMqttConnecting: false,
      isMqttConnected: false,
      clearDeviceCode: true,
      clearError: true,
    );
    _addLog('Tracking stopped.');
  }

  void _refreshSnapshot() {
    final snapshot = _gnssService.getCurrentSnapshot();
    state = state.copyWith(snapshot: Map<String, dynamic>.from(snapshot));
  }

  Future<void> _publishTelemetry() async {
    if (!state.isMqttConnected) {
      return;
    }

    final tracking = state.snapshot['tracking'];
    if (tracking is! Map || tracking['lat'] == null || tracking['lng'] == null) {
      return;
    }

    try {
      _mqttService.publishTelemetry(
        state.snapshot,
        deviceIdentifier: state.deviceCode,
      );
      _addLog('Publish OK to MQTT.');
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      _addLog('Publish FAILED: $error');
    }
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final nextLogs = <String>['[$stamp] $message', ...state.logs];
    if (nextLogs.length > 150) {
      nextLogs.removeRange(150, nextLogs.length);
    }
    state = state.copyWith(logs: nextLogs);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _publishTimer?.cancel();
    _gnssService.stopCollection();
    _mqttService.disconnect();
    super.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(
    ref.watch(gnssServiceProvider),
    ref.watch(mqttServiceProvider),
  );
});

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_environment.dart';
import 'gnss_service.dart';
import 'mqtt_service.dart';

const _trackingEnabledKey = 'tracking_enabled';
const _trackingDeviceCodeKey = 'tracking_device_code';

class TrackingBackgroundService {
  TrackingBackgroundService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;

  static Future<void> initialize() async {
    if (_configured) {
      return;
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        initialNotificationTitle: 'GNSS tracking',
        initialNotificationContent: 'Preparing telemetry stream',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    _configured = true;
  }

  static Future<bool> isRunning() => _service.isRunning();

  static Future<void> start({required String deviceCode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, true);
    await prefs.setString(_trackingDeviceCodeKey, deviceCode);

    if (await _service.isRunning()) {
      return;
    }

    await _service.startService();
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, false);

    if (await _service.isRunning()) {
      _service.invoke('stopTracking');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await dotenv.load(fileName: AppEnvironment.envFileName);

  final prefs = await SharedPreferences.getInstance();
  final trackingEnabled = prefs.getBool(_trackingEnabledKey) ?? false;
  final deviceCode = prefs.getString(_trackingDeviceCodeKey)?.trim();

  if (!trackingEnabled || deviceCode == null || deviceCode.isEmpty) {
    await service.stopSelf();
    return;
  }

  final gnssService = GnssService();
  final mqttService = MqttService();
  var stopped = false;

  service.on('stopTracking').listen((_) async {
    stopped = true;
    gnssService.stopCollection();
    mqttService.disconnect();
    await service.stopSelf();
  });

  try {
    await gnssService.startCollection();
  } catch (_) {
    await service.stopSelf();
    return;
  }

  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (stopped) {
      timer.cancel();
      return;
    }

    try {
      if (!mqttService.isConnected) {
        final connected = await mqttService.connect(
          deviceCode,
          clientIdentifier: 'gnss_app_$deviceCode',
        );

        if (!connected) {
          return;
        }
      }

      final snapshot = gnssService.getCurrentSnapshot();
      final tracking = snapshot['tracking'];
      if (tracking is! Map || tracking['lat'] == null || tracking['lng'] == null) {
        return;
      }

      mqttService.publishTelemetry(
        Map<String, dynamic>.from(snapshot),
        deviceIdentifier: deviceCode,
      );
    } catch (e) {
      final message = e.toString();
      if (message.contains('MQTT_BROKER_URL') ||
          message.contains('Invalid MQTT_BROKER_URL') ||
          message.contains('MQTT_TOPIC_PATTERN')) {
        timer.cancel();
        mqttService.disconnect();
        await service.stopSelf();
      }
    }
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await dotenv.load(fileName: AppEnvironment.envFileName);
  return true;
}

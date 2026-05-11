import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gnss_app/constants/app_environment.dart';

class AppConstants {
  static String get baseUrl {
    final configured = dotenv.env['BASE_API_URL']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return _normalizeConfiguredBaseUrl(configured);
    }

    if (AppEnvironment.isProduction) {
      throw StateError(
        'BASE_API_URL is required when APP_ENV=prod. Please set it in .env.prod.',
      );
    }

    return _defaultBaseUrl;
  }

  static String _normalizeConfiguredBaseUrl(String configured) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return configured;
    }

    final uri = Uri.tryParse(configured);
    if (uri == null || uri.host.isEmpty) {
      return configured;
    }

    final host = uri.host.toLowerCase();
    if (host != 'localhost' && host != '127.0.0.1' && host != '::1') {
      return configured;
    }

    return uri.replace(host: '10.0.2.2').toString();
  }

  static String get _defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }

    return 'http://localhost:5000/api';
  }

  static const int sendIntervalSeconds = 5;

  static String getTelemetryTopic(String deviceCode) {
    final pattern = dotenv.env['MQTT_TOPIC_PATTERN'];
    return pattern?.replaceAll('+', deviceCode) ?? '';
  }
}

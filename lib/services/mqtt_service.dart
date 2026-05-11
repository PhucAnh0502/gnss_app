import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gnss_app/constants/app_constants.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttServerClient? _client;
  String? _activeDeviceIdentifier;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<bool> connect(String deviceIdentifier, {String? clientIdentifier}) async {
    if (isConnected) {
      _activeDeviceIdentifier = deviceIdentifier;
      return true;
    }

    final brokerRaw = dotenv.env['MQTT_BROKER_URL']?.trim();
    if (brokerRaw == null || brokerRaw.isEmpty) {
      throw Exception('MQTT_BROKER_URL is missing in .env');
    }

    final uri = Uri.tryParse(brokerRaw);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Invalid MQTT_BROKER_URL: $brokerRaw');
    }

    final useTls = uri.scheme.toLowerCase() == 'mqtts';
    final preferredPort = uri.hasPort ? uri.port : (useTls ? 8883 : 1883);
    final resolvedClientId =
        clientIdentifier ?? 'gnss_app_${DateTime.now().millisecondsSinceEpoch}';

    final username = dotenv.env['MQTT_USERNAME']?.trim();
    final password = dotenv.env['MQTT_PASSWORD']?.trim();
    final attempt = _MqttConnectAttempt(
      host: uri.host,
      port: preferredPort,
      secure: useTls,
      username: _isNotEmpty(username) ? username : null,
      password: _isNotEmpty(username) ? (password ?? '') : null,
    );

    final connected = await _tryConnect(
      attempt: attempt,
      clientIdentifier: resolvedClientId,
    );
    if (connected) {
      _activeDeviceIdentifier = deviceIdentifier;
      return true;
    }

    return false;
  }

  Future<bool> _tryConnect({
    required _MqttConnectAttempt attempt,
    required String clientIdentifier,
  }) async {
    final client = MqttServerClient.withPort(
      attempt.host,
      clientIdentifier,
      attempt.port,
    )
      ..secure = attempt.secure
      ..setProtocolV311()
      ..keepAlivePeriod = 60
      ..autoReconnect = false
      ..resubscribeOnAutoReconnect = false
      ..logging(on: false)
      ..onConnected = () {}
      ..onDisconnected = () {};

    if (attempt.secure) {
      client.onBadCertificate = (Object _) => true;
    }

    // Keep CONNECT packet minimal and standards-compliant unless a full LWT
    // (topic + payload + qos + retain) is explicitly needed.
    var message = MqttConnectMessage()
      .withClientIdentifier(clientIdentifier)
      .startClean();

    client.connectionMessage = message;

    try {
      await client.connect(attempt.username, attempt.password).timeout(
            const Duration(seconds: 30),
          );
    } catch (error) {
      client.disconnect();
      return false;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      client.disconnect();
      return false;
    }

    _client?.disconnect();
    _client = client;
    return true;
  }

  void publishJson(
    String topic,
    Map<String, dynamic> payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) {
    final client = _client;
    if (client == null || !isConnected) {
      throw Exception('MQTT client is not connected.');
    }

    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(jsonEncode(payload));
    final bytes = builder.payload;
    if (bytes == null) {
      throw Exception('Failed to build MQTT payload.');
    }

    client.publishMessage(topic, qos, bytes, retain: retain);
  }

  void publishTelemetry(
    Map<String, dynamic> payload, {
    String? deviceIdentifier,
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) {
    final resolvedIdentifier = deviceIdentifier ?? _activeDeviceIdentifier;
    if (resolvedIdentifier == null || resolvedIdentifier.isEmpty) {
      throw Exception('Device identifier is missing. Call connect(deviceIdentifier) first.');
    }

    final topic = AppConstants.getTelemetryTopic(resolvedIdentifier);
    if (topic.isEmpty) {
      throw Exception('MQTT_TOPIC_PATTERN is missing or invalid in .env');
    }

    final normalizedPayload = _normalizeTelemetryPayload(
      payload,
      deviceIdentifier: resolvedIdentifier,
    );
    publishJson(topic, normalizedPayload, qos: qos, retain: retain);
  }

  Map<String, dynamic> _normalizeTelemetryPayload(
    Map<String, dynamic> payload, {
    required String deviceIdentifier,
  }) {
    final trackingRaw = payload['tracking'];
    final tracking = trackingRaw is Map<String, dynamic>
        ? trackingRaw
        : <String, dynamic>{};

    final source = tracking.isNotEmpty ? tracking : payload;
    final lat = _asDouble(source['lat']);
    final lng = _asDouble(source['lng']);

    if (lat == null || lng == null) {
      throw Exception('Telemetry payload requires lat and lng.');
    }

    final timestampSeconds = _toEpochSeconds(source['ts']);

    final normalized = <String, dynamic>{
      'deviceCode': payload['deviceCode'] ?? deviceIdentifier,
      'lat': lat,
      'lng': lng,
      'sp': _asDouble(source['sp']) ?? 0.0,
      'alt': _asDouble(source['alt']) ?? 0.0,
      'hd': _asDouble(source['hd']) ?? 0.0,
      'hdop': _asDouble(source['hdop']) ?? 0.0,
      'sat': _asInt(source['sat'] ?? source['satCount']) ?? 0,
      'rssi': _asInt(source['rssi']) ?? 0,
      'ts': timestampSeconds,
    };

    final acc = _asDouble(source['acc']);
    if (acc != null) {
      normalized['acc'] = acc;
    }

    final satUsed = _asInt(source['satUsed']);
    if (satUsed != null) {
      normalized['satUsed'] = satUsed;
    }

    final avgCn0 = _asDouble(source['avgCn0']);
    if (avgCn0 != null) {
      normalized['avgCn0'] = avgCn0;
    }

    final raw = payload['raw'];
    if (raw is Map<String, dynamic>) {
      normalized['raw'] = raw;
    }

    return normalized;
  }

  int _toEpochSeconds(dynamic value) {
    if (value == null) {
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    if (value is int) {
      return value > 9999999999 ? value ~/ 1000 : value;
    }

    if (value is double) {
      if (!value.isFinite) {
        return DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
      final asInt = value.toInt();
      return asInt > 9999999999 ? asInt ~/ 1000 : asInt;
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }

    final fromIso = DateTime.tryParse(text);
    if (fromIso != null) {
      return fromIso.millisecondsSinceEpoch ~/ 1000;
    }

    final numeric = num.tryParse(text);
    if (numeric != null) {
      if (!numeric.isFinite) {
        return DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
      final asInt = numeric.toInt();
      return asInt > 9999999999 ? asInt ~/ 1000 : asInt;
    }

    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      final asDouble = value.toDouble();
      return asDouble.isFinite ? asDouble : null;
    }
    final parsed = double.tryParse(value.toString());
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      if (!value.isFinite) {
        return null;
      }
      return value.toInt();
    }
    final parsed = int.tryParse(value.toString());
    return parsed;
  }

  void disconnect() {
    _client?.disconnect();
    _client = null;
    _activeDeviceIdentifier = null;
  }

  String? get activeDeviceIdentifier => _activeDeviceIdentifier;
  MqttServerClient? get client => _client;
}

class _MqttConnectAttempt {
  const _MqttConnectAttempt({
    required this.host,
    required this.port,
    required this.secure,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final bool secure;
  final String? username;
  final String? password;
}

bool _isNotEmpty(String? value) => value != null && value.trim().isNotEmpty;

import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;
  final Map<String, StreamController<Map<String, dynamic>>> _deviceStreams = {};
  final StreamController<Map<String, dynamic>> _statusUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _socket?.connected == true;

  Future<bool> connect({String? clientId}) async {
    if (isConnected) {
      print('[Socket] Already connected');
      return true;
    }

    try {
      final baseUrl = dotenv.env['BASE_API_URL']?.trim();
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_API_URL is missing in .env');
      }

      final uri = Uri.tryParse(baseUrl);
      if (uri == null || uri.host.isEmpty) {
        throw Exception('Invalid BASE_API_URL: $baseUrl');
      }

      // Extract scheme and host for WebSocket URL
      // If it's http://10.0.2.2:5000/api, we want ws://10.0.2.2:5000
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

      print('[Socket] Attempting connection to: $wsUrl');

      _socket = IO.io(
        wsUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(double.maxFinite)
            .build(),
      );

      _setupListeners();

      // Wait for connection with proper timeout and retry
      int retries = 0;
      int maxRetries = 3;
      
      while (!isConnected && retries < maxRetries) {
        print('[Socket] Waiting for connection... (${retries + 1}/$maxRetries)');
        await Future.delayed(const Duration(seconds: 3));
        retries++;
      }

      if (!isConnected) {
        print('[Socket] Failed to connect after ${retries * 3}s - will retry on next attempt');
        return false;
      }
      
      print('[Socket] Connected successfully');
      return true;
    } catch (error) {
      print('[Socket] Connection error: $error');
      return false;
    }
  }

  void _setupListeners() {
    _socket?.on('connect', (_) {
      print('[Socket] Connected to server');
    });

    _socket?.on('disconnect', (_) {
      print('[Socket] Disconnected from server');
    });

    _socket?.on('connect_error', (error) {
      print('[Socket] Connection error: $error');
    });

    _socket?.on('error', (error) {
      print('[Socket] Error: $error');
    });

    // Listen to all live:deviceCode events
    _socket?.onAny((String event, dynamic data) {
      if (event.startsWith('live:')) {
        final deviceCode = event.substring(5); // Extract deviceCode from 'live:XXX'
        final payload = data is Map<String, dynamic>
            ? data
            : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});

        print('[Socket] Received live update for device: $deviceCode');

        // Emit to broadcast stream
        _statusUpdatesController.add({
          'deviceCode': deviceCode,
          ...payload,
        });

        // Emit to device-specific stream
        _getDeviceStream(deviceCode).add(payload);
      }
    });
  }

  Stream<Map<String, dynamic>> watchDeviceStatus(String deviceCode) {
    return _getDeviceStream(deviceCode).stream;
  }

  Stream<Map<String, dynamic>> watchAllDeviceUpdates() {
    return _statusUpdatesController.stream;
  }

  StreamController<Map<String, dynamic>> _getDeviceStream(String deviceCode) {
    if (!_deviceStreams.containsKey(deviceCode)) {
      _deviceStreams[deviceCode] =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    return _deviceStreams[deviceCode]!;
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;

    // Clean up streams
    for (final controller in _deviceStreams.values) {
      controller.close();
    }
    _deviceStreams.clear();

    _statusUpdatesController.close();
  }

  IO.Socket? get socket => _socket;
}

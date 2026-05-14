import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_model.dart';
import '../services/device_service.dart';
import '../services/socket_service.dart';
import '../services/diagnostic_service.dart';

final deviceServiceProvider = Provider((ref) => DeviceService());
final socketServiceProvider = Provider((ref) => SocketService());
final diagnosticServiceProvider = Provider((ref) => DiagnosticService());

final selectedDeviceProvider = StateProvider<DeviceModel?>((ref) => null);

final devicesListProvider = FutureProvider<List<DeviceModel>>((ref) async {
  final service = ref.watch(deviceServiceProvider);
  return await service.getMyDevices();
});

// Stream provider for realtime device updates
final realtimeDevicesProvider =
    StreamProvider<List<DeviceModel>>((ref) async* {
  final socketService = ref.watch(socketServiceProvider);
  final deviceService = ref.watch(deviceServiceProvider);
  final diagnosticService = ref.watch(diagnosticServiceProvider);

  // Log network info on startup
  await diagnosticService.logNetworkInfo();

  // Try to connect socket if not already connected
  bool socketConnected = false;
  if (!socketService.isConnected) {
    try {
      socketConnected = await socketService.connect();
      print('[Device Stream] Socket connected: $socketConnected');
    } catch (e) {
      print('[Device Stream] Socket connection error: $e');
      socketConnected = false;
    }
  } else {
    socketConnected = true;
  }

  // Fetch initial list
  final initialDevices = await deviceService.getMyDevices();
  yield initialDevices;

  // Keep track of current device list
  var currentDevices = initialDevices;
  final deviceMap = {for (var d in initialDevices) d.id: d};

  if (socketConnected) {
    // If socket is connected, use realtime updates
    print('[Device Stream] Using realtime Socket.io mode');
    final stream = socketService.watchAllDeviceUpdates();
    await for (final _ in stream) {
      try {
        // Refresh full list to get latest data with status/lastPing updates
        final refreshed = await deviceService.getMyDevices();
        currentDevices = refreshed;
        deviceMap.clear();
        deviceMap.addAll({for (var d in refreshed) d.id: d});
        yield List<DeviceModel>.from(currentDevices);
      } catch (e) {
        print('[Device Stream] Failed to refresh devices: $e');
        // Continue emitting current devices on error
        yield List<DeviceModel>.from(currentDevices);
      }
    }
  } else {
    // Fallback: polling every 30 seconds if socket connection fails
    print('[Device Stream] Socket connection failed - using polling fallback (30s interval)');
    var pollCount = 0;
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      pollCount++;
      try {
        final refreshed = await deviceService.getMyDevices();
        currentDevices = refreshed;
        deviceMap.clear();
        deviceMap.addAll({for (var d in refreshed) d.id: d});
        yield List<DeviceModel>.from(currentDevices);
        if (pollCount % 6 == 0) {
          // Try to reconnect socket every 3 minutes (6 * 30s)
          try {
            socketConnected = await socketService.connect();
            if (socketConnected) {
              print('[Device Stream] Socket reconnected! Switching to realtime mode');
              break; // Exit polling, go back to socket listening
            }
          } catch (e) {
            print('[Device Stream] Socket reconnect attempt failed');
          }
        }
      } catch (e) {
        print('[Device Stream] Polling failed: $e');
        yield List<DeviceModel>.from(currentDevices);
      }
    }
  }
});

class DeviceActionNotifier extends StateNotifier<AsyncValue<void>> {
  final DeviceService _service;
  final Ref _ref;

  DeviceActionNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> addDevice(String name, String code) async {
    state = const AsyncValue.loading();
    try {
      await _service.addDevice(name, code);
      state = const AsyncValue.data(null);
      _ref.invalidate(realtimeDevicesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateDevice(String id, String name) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateDevice(id, name);
      state = const AsyncValue.data(null);
      _ref.invalidate(realtimeDevicesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteDevice(String id) async {
    state = const AsyncValue.loading();
    try {
      await _service.deleteDevice(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(realtimeDevicesProvider);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final deviceActionProvider = StateNotifierProvider<DeviceActionNotifier, AsyncValue<void>>(
  (ref) => DeviceActionNotifier(ref.watch(deviceServiceProvider), ref),
);

// Get current device code stored in SharedPreferences or resolve from Android device ID
final currentDeviceCodeProvider = FutureProvider<String?>((ref) async {
  try {
    // First try to get from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final storedCode = prefs.getString('tracking_device_code')?.trim();
    if (storedCode != null && storedCode.isNotEmpty) {
      return storedCode;
    }

    // If not stored, resolve Android device ID
    if (!kIsWeb) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id.trim();
      } catch (e) {
        print('[Device Code Provider] Error getting Android device ID: $e');
      }
    }
    
    return null;
  } catch (e) {
    print('[Device Code Provider] Error: $e');
    return null;
  }
});

// Get current device from the list based on device code
final currentPhysicalDeviceProvider = FutureProvider<DeviceModel?>((ref) async {
  final currentDeviceCode = await ref.watch(currentDeviceCodeProvider.future);
  final devicesAsync = ref.watch(realtimeDevicesProvider);
  
  return devicesAsync.maybeWhen(
    data: (devices) {
      if (currentDeviceCode == null || currentDeviceCode.isEmpty || devices.isEmpty) {
        return null;
      }
      
      // Find device that matches current device code
      try {
        final device = devices.firstWhere(
          (d) => d.deviceCode.toLowerCase() == currentDeviceCode.toLowerCase(),
          orElse: () => devices.first,
        );
        return device;
      } catch (e) {
        print('[Current Device Provider] Error finding matching device: $e');
        return devices.isNotEmpty ? devices.first : null;
      }
    },
    orElse: () => null,
  );
});
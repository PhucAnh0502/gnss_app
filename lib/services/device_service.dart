import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/device_model.dart';

class DeviceService {
  final _dio = ApiService().dio;

  Future<List<DeviceModel>> getMyDevices() async {
    try {
      final response = await _dio.get('/devices');
      final List data = response.data['data'];
      return data.map((json) => DeviceModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<DeviceModel> getDeviceById(String id) async {
    try {
      final response = await _dio.get('/devices/$id');
      return DeviceModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<DeviceModel> addDevice(String name, String code) async {
    try {
      final response = await _dio.post(
        '/devices',
        data: {'deviceName': name, 'deviceCode': code},
      );
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final device = payload['device'];
        if (device is Map<String, dynamic>) {
          return DeviceModel.fromJson(device);
        }
      }
      throw Exception('Device created, but the server response was invalid.');
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<DeviceModel> updateDevice(String id, String name) async {
    try {
      final response = await _dio.put(
        '/devices/$id',
        data: {'deviceName': name},
      );
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final data = payload['data'];
        if (data is Map<String, dynamic>) {
          return DeviceModel.fromJson(data);
        }
      }
      throw Exception('Device updated, but the server response was invalid.');

    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<void> deleteDevice(String id) async {
    try {
      await _dio.delete('/devices/$id');
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final messages = <String>[];
          for (final item in errors) {
            if (item is Map<String, dynamic>) {
              final message = item['message']?.toString();
              if (message != null && message.isNotEmpty) {
                messages.add(message);
              }
            }
          }
          if (messages.isNotEmpty) {
            return messages.join('\n');
          }
        }

        final message = data['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      return error.message ?? 'Request failed. Please try again.';
    }

    return error.toString();
  }
}
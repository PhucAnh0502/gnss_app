import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/tracking_point_model.dart';

class TrackingService {
  final _dio = ApiService().dio;

  Future<TrackingHistoryBundle> getDeviceHistory(
    String deviceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get(
        '/tracking/history/$deviceId',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );

      return TrackingHistoryBundle.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  Future<TrackingPointModel?> getLatestDeviceLocation(String deviceId) async {
    try {
      final response = await _dio.get('/tracking/latest/$deviceId');
      final payload = response.data;
      if (payload is Map<String, dynamic>) {
        final data = payload['data'];
        if (data is Map<String, dynamic>) {
          return TrackingPointModel.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
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

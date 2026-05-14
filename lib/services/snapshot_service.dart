import 'dart:io';

import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/snapshot_model.dart';

class SnapshotService {
  final Dio _dio = ApiService().dio;

  Future<Map<String, dynamic>> initSnapshot(Map<String, dynamic> metadata) async {
    final response = await _dio.post('/snapshots/init', data: metadata);
    final data = Map<String, dynamic>.from(response.data as Map);
    return data;
  }

  Future<SnapshotModel> uploadFile(String snapshotId, File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
    });

    final response = await _dio.post('/snapshots/$snapshotId/upload', data: formData);
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SnapshotModel.fromJson(data);
  }

  Future<List<SnapshotModel>> listSnapshots({
    required String deviceId,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final response = await _dio.get(
      '/snapshots/devices/$deviceId',
      queryParameters: {
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
        if (status != null) 'status': status,
      },
    );

    final payload = response.data;
    final items = payload is Map<String, dynamic> ? payload['data'] : null;
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => SnapshotModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return const <SnapshotModel>[];
  }

  Future<SnapshotModel> attachToTracking({
    required String snapshotId,
    required String trackingId,
  }) async {
    final response = await _dio.post('/snapshots/attach-to-tracking', data: {
      'snapshotId': snapshotId,
      'trackingId': trackingId,
    });
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    return SnapshotModel.fromJson(data);
  }
}
import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';

import '../models/snapshot_model.dart';
import '../services/snapshot_service.dart';

final snapshotService = SnapshotService();

class SnapshotState {
  const SnapshotState({
    this.items = const <SnapshotModel>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<SnapshotModel> items;
  final bool isLoading;
  final String? errorMessage;

  SnapshotState copyWith({
    List<SnapshotModel>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SnapshotState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SnapshotNotifier extends StateNotifier<SnapshotState> {
  SnapshotNotifier(this._service) : super(const SnapshotState());

  final SnapshotService _service;

  Future<void> loadSnapshots(String deviceId, {DateTime? from, DateTime? to, String? status}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _service.listSnapshots(deviceId: deviceId, from: from, to: to, status: status);
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<SnapshotModel?> createAndUpload({
    required Map<String, dynamic> metadata,
    required String filePath,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final initResponse = await _service.initSnapshot(metadata);
      final data = initResponse['data'];
      final snapshotId = data is Map ? data['id']?.toString() : initResponse['snapshotId']?.toString();
      if (snapshotId == null || snapshotId.isEmpty) {
        throw Exception('Snapshot init did not return an id');
      }

      final uploaded = await _service.uploadFile(snapshotId, File(filePath));
      final updatedItems = [uploaded, ...state.items.where((item) => item.id != uploaded.id)];
      state = state.copyWith(items: updatedItems, isLoading: false, clearError: true);
      return uploaded;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final snapshotProvider = StateNotifierProvider<SnapshotNotifier, SnapshotState>((ref) {
  return SnapshotNotifier(snapshotService);
});
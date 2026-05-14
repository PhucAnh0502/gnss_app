class SnapshotModel {
  final String id;
  final String deviceId;
  final String? trackingId;
  final DateTime capturedAt;
  final String captureMode;
  final double? latitude;
  final double? longitude;
  final double altitude;
  final double speed;
  final double heading;
  final double hdop;
  final int satellitesCount;
  final int satellitesUsed;
  final double avgCn0;
  final String? imageBucket;
  final String? imagePath;
  final String? imageUrl;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? note;
  final String syncStatus;

  const SnapshotModel({
    required this.id,
    required this.deviceId,
    required this.capturedAt,
    required this.captureMode,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.hdop,
    required this.satellitesCount,
    required this.satellitesUsed,
    required this.avgCn0,
    required this.syncStatus,
    this.trackingId,
    this.latitude,
    this.longitude,
    this.imageBucket,
    this.imagePath,
    this.imageUrl,
    this.mimeType,
    this.fileSizeBytes,
    this.note,
  });

  factory SnapshotModel.fromJson(Map<String, dynamic> json) {
    return SnapshotModel(
      id: (json['id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      trackingId: json['trackingId']?.toString() ?? json['tracking_id']?.toString(),
      capturedAt: DateTime.tryParse((json['capturedAt'] ?? json['captured_at'] ?? '').toString()) ?? DateTime.now(),
      captureMode: (json['captureMode'] ?? json['capture_mode'] ?? 'manual').toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      altitude: _asDouble(json['altitude']) ?? 0,
      speed: _asDouble(json['speed']) ?? 0,
      heading: _asDouble(json['heading']) ?? 0,
      hdop: _asDouble(json['hdop']) ?? 0,
      satellitesCount: _asInt(json['satellites_count']) ?? 0,
      satellitesUsed: _asInt(json['satellites_used']) ?? 0,
      avgCn0: _asDouble(json['avg_cn0']) ?? 0,
      imageBucket: (json['imageBucket'] ?? json['image_bucket'])?.toString(),
      imagePath: (json['imagePath'] ?? json['image_path'])?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      mimeType: (json['mimeType'] ?? json['mime_type'])?.toString(),
      fileSizeBytes: _asInt(json['fileSizeBytes'] ?? json['file_size_bytes']),
      note: json['note']?.toString(),
      syncStatus: (json['syncStatus'] ?? json['sync_status'] ?? 'pending').toString(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
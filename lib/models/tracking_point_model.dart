class TrackingPointModel {
  final String id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double altitude;
  final double speed;
  final double heading;
  final double hdop;
  final int satellitesCount;
  final int satellitesUsed;
  final double avgCn0;

  TrackingPointModel({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.hdop,
    required this.satellitesCount,
    required this.satellitesUsed,
    required this.avgCn0,
  });

  factory TrackingPointModel.fromJson(Map<String, dynamic> json) {
    final location = json['location'];
    final coordinates = location is Map<String, dynamic>
        ? location['coordinates']
        : null;

    double latitude = _asDouble(json['lat']) ?? 0;
    double longitude = _asDouble(json['lng']) ?? 0;

    if (coordinates is List && coordinates.length >= 2) {
      longitude = _asDouble(coordinates[0]) ?? longitude;
      latitude = _asDouble(coordinates[1]) ?? latitude;
    }

    return TrackingPointModel(
      id: (json['id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      latitude: latitude,
      longitude: longitude,
      timestamp: _parseDateTime(json['timestamp']) ?? DateTime.now(),
      altitude: _asDouble(json['altitude']) ?? 0,
      speed: _asDouble(json['speed']) ?? 0,
      heading: _asDouble(json['heading']) ?? 0,
      hdop: _asDouble(json['hdop']) ?? 0,
      satellitesCount: _asInt(json['satellites_count']) ?? 0,
      satellitesUsed: _asInt(json['satellites_used']) ?? 0,
      avgCn0: _asDouble(json['avg_cn0']) ?? 0,
    );
  }

  String get timeLabel {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get dateLabel {
    final local = timestamp.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
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

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      if (!value.isFinite) {
        return null;
      }
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}

class TrackingHistoryBundle {
  final List<TrackingPointModel> points;
  final double totalDistanceMeters;
  final int pointCount;

  const TrackingHistoryBundle({
    required this.points,
    required this.totalDistanceMeters,
    required this.pointCount,
  });

  factory TrackingHistoryBundle.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final summary = json['summary'];

    final points = data is List
        ? data
            .whereType<Map>()
            .map((item) => TrackingPointModel.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <TrackingPointModel>[];

    final summaryMap = summary is Map<String, dynamic>
        ? summary
        : <String, dynamic>{};

    return TrackingHistoryBundle(
      points: points,
      totalDistanceMeters: TrackingPointModel._asDouble(summaryMap['totalDistanceMeter']) ?? 0,
      pointCount: TrackingPointModel._asInt(summaryMap['points']) ?? points.length,
    );
  }

  bool get hasPoints => points.isNotEmpty;
  TrackingPointModel? get latestPoint => points.isEmpty ? null : points.last;
}

enum DeviceStatus {active, inactive, maintenance}

class DeviceModel {
  final String id;
  final String deviceName;
  final String deviceCode;
  final String status;
  final DateTime? lastPing;
  final String userId;

  DeviceModel({
    required this.id,
    required this.deviceName,
    required this.deviceCode,
    required this.status,
    this.lastPing,
    required this.userId,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      deviceName: json['deviceName'],
      deviceCode: json['deviceCode'],
      status: json['status'] ?? 'inactive',
      lastPing: json['lastPing'] != null ? DateTime.parse(json['lastPing']) : null,
      userId: json['userId'],
    );
  }
}
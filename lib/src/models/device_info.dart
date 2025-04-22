import 'business_card.dart';

/// Information about an NFC device
class NFCDeviceInfo {
  final String deviceId;
  final NFCDeviceType deviceType;
  final String? name;
  final DateTime activatedAt;
  final bool isActive;
  
  NFCDeviceInfo({
    required this.deviceId,
    required this.deviceType,
    this.name,
    required this.activatedAt,
    this.isActive = true,
  });
  
  /// Creates a NFCDeviceInfo from JSON
  factory NFCDeviceInfo.fromJson(Map<String, dynamic> json) {
    return NFCDeviceInfo(
      deviceId: json['deviceId'],
      deviceType: NFCDeviceType.values.firstWhere(
        (e) => e.toString() == 'NFCDeviceType.${json['deviceType']}',
        orElse: () => NFCDeviceType.card,
      ),
      name: json['name'],
      activatedAt: DateTime.parse(json['activatedAt']),
      isActive: json['isActive'] ?? true,
    );
  }
  
  /// Converts NFCDeviceInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceType': deviceType.toString().split('.').last,
      'name': name,
      'activatedAt': activatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}
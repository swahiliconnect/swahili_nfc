/// Represents a record of a card being scanned
class ScanRecord {
  final String cardId;
  final DateTime timestamp;
  final String? deviceModel;
  final String? deviceOs;
  final String? location;
  final Map<String, dynamic>? metadata;
  
  ScanRecord({
    required this.cardId,
    required this.timestamp,
    this.deviceModel,
    this.deviceOs,
    this.location,
    this.metadata,
  });
  
  /// Creates a ScanRecord from JSON
  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      cardId: json['cardId'],
      timestamp: DateTime.parse(json['timestamp']),
      deviceModel: json['deviceModel'],
      deviceOs: json['deviceOs'],
      location: json['location'],
      metadata: json['metadata'],
    );
  }
  
  /// Converts ScanRecord to JSON
  Map<String, dynamic> toJson() {
    return {
      'cardId': cardId,
      'timestamp': timestamp.toIso8601String(),
      'deviceModel': deviceModel,
      'deviceOs': deviceOs,
      'location': location,
      'metadata': metadata,
    };
  }
}
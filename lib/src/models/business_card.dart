import 'dart:typed_data';

/// Security level for NFC cards
enum SecurityLevel {
  /// Standard NDEF records, readable by any NFC reader
  open,

  /// Password-protected with simple PIN/password
  basic,

  /// Encrypted data with app-specific decryption
  enhanced,

  /// Digital signatures and authentication tokens
  premium,
}

/// Type of NFC card or device
enum NFCDeviceType {
  /// Standard NFC card
  card,

  /// NFC tag
  tag,

  /// NFC wristband
  wristband,

  /// Other NFC device
  other,
}

/// Type of business card
enum CardType {
  /// Personal business card
  personal,

  /// Company business card
  company,

  /// Temporary business card
  temporary,

  /// Event-specific business card
  event,
}

/// Data structure representing a business card
class BusinessCardData {
  // Core data
  final String name;
  final String? company;
  final String? position;
  final String? email;
  final String? phone;

  // Extended data
  final Map<String, String> social;
  final Map<String, String> custom;
  final Uint8List? profileImage;

  // Metadata
  final String cardId;
  final DateTime createdAt;
  final CardType cardType;

  // Security
  final SecurityLevel securityLevel;
  final bool isTemporary;

  /// Creates a new business card data instance
  BusinessCardData({
    required this.name,
    this.company,
    this.position,
    this.email,
    this.phone,
    this.social = const {},
    this.custom = const {},
    this.profileImage,
    String? cardId,
    DateTime? createdAt,
    this.cardType = CardType.personal,
    this.securityLevel = SecurityLevel.open,
    this.isTemporary = false,
  })  : cardId = cardId ?? _generateCardId(),
        createdAt = createdAt ?? DateTime.now();

  /// Creates a BusinessCardData from JSON
  factory BusinessCardData.fromJson(Map<String, dynamic> json) {
    return BusinessCardData(
      name: json['name'],
      company: json['company'],
      position: json['position'],
      email: json['email'],
      phone: json['phone'],
      social: Map<String, String>.from(json['social'] ?? {}),
      custom: Map<String, String>.from(json['custom'] ?? {}),
      profileImage: json['profileImage'] != null
          ? Uint8List.fromList(List<int>.from(json['profileImage']))
          : null,
      cardId: json['cardId'],
      createdAt: DateTime.parse(json['createdAt']),
      cardType: CardType.values.firstWhere(
        (e) => e.toString() == 'CardType.${json['cardType']}',
        orElse: () => CardType.personal,
      ),
      securityLevel: SecurityLevel.values.firstWhere(
        (e) => e.toString() == 'SecurityLevel.${json['securityLevel']}',
        orElse: () => SecurityLevel.open,
      ),
      isTemporary: json['isTemporary'] ?? false,
    );
  }

  /// Converts BusinessCardData to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'company': company,
      'position': position,
      'email': email,
      'phone': phone,
      'social': social,
      'custom': custom,
      'profileImage': profileImage?.toList(),
      'cardId': cardId,
      'createdAt': createdAt.toIso8601String(),
      'cardType': cardType.toString().split('.').last,
      'securityLevel': securityLevel.toString().split('.').last,
      'isTemporary': isTemporary,
    };
  }

  /// Generates a unique card ID
  static String _generateCardId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

/// Security credentials for protected cards
class SecurityCredentials {
  final String? password;
  final String? encryptionKey;
  final DateTime? expiration;

  SecurityCredentials({
    this.password,
    this.encryptionKey,
    this.expiration,
  });
}

/// Security options for card activation
class SecurityOptions {
  final SecurityLevel level;
  final String? password;
  final DateTime? expiry;

  SecurityOptions({
    required this.level,
    this.password,
    this.expiry,
  });
}

/// Configuration for analytics collection
class AnalyticsConfig {
  final bool collectLocationData;
  final bool collectDeviceInfo;
  final bool collectTimestamps;

  AnalyticsConfig({
    this.collectLocationData = false,
    this.collectDeviceInfo = true,
    this.collectTimestamps = true,
  });
}

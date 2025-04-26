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

  /// Creates a BusinessCardData from JSON with improved null handling
  factory BusinessCardData.fromJson(Map<String, dynamic> json) {
    // Handle null, empty maps, and type conversion for social media
    Map<String, String> socialMap = {};
    if (json['social'] != null) {
      if (json['social'] is Map) {
        // Try to convert all values to strings
        (json['social'] as Map).forEach((key, value) {
          socialMap[key.toString()] = value != null ? value.toString() : '';
        });
      }
    }
    
    // Handle null, empty maps, and type conversion for custom fields
    Map<String, String> customMap = {};
    if (json['custom'] != null) {
      if (json['custom'] is Map) {
        // Try to convert all values to strings
        (json['custom'] as Map).forEach((key, value) {
          customMap[key.toString()] = value != null ? value.toString() : '';
        });
      }
    }
    
    // Handle profile image if present
    Uint8List? profileImageData;
    if (json['profileImage'] != null) {
      try {
        if (json['profileImage'] is List) {
          profileImageData = Uint8List.fromList(List<int>.from(json['profileImage']));
        }
      } catch (e) {
        // Ignore errors with profile image
        profileImageData = null;
      }
    }
    
    // Parse creation date with fallback
    DateTime createdAt;
    try {
      if (json['createdAt'] != null) {
        createdAt = DateTime.parse(json['createdAt']);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      // Fallback if date parsing fails
      createdAt = DateTime.now();
    }
    
    return BusinessCardData(
      name: json['name'] ?? 'Unknown',
      company: json['company'],
      position: json['position'],
      email: json['email'],
      phone: json['phone'],
      social: socialMap,
      custom: customMap,
      profileImage: profileImageData,
      cardId: json['cardId'] ?? _generateCardId(),
      createdAt: createdAt,
      cardType: _parseCardType(json['cardType']),
      securityLevel: _parseSecurityLevel(json['securityLevel']),
      isTemporary: json['isTemporary'] ?? false,
    );
  }

  /// Helper method to parse CardType safely
  static CardType _parseCardType(dynamic value) {
    if (value == null) return CardType.personal;
    
    if (value is CardType) return value;
    
    if (value is String) {
      try {
        return CardType.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
          orElse: () => CardType.personal,
        );
      } catch (_) {
        // Return default on any error
        return CardType.personal;
      }
    }
    
    return CardType.personal;
  }

  /// Helper method to parse SecurityLevel safely
  static SecurityLevel _parseSecurityLevel(dynamic value) {
    if (value == null) return SecurityLevel.open;
    
    if (value is SecurityLevel) return value;
    
    if (value is String) {
      try {
        return SecurityLevel.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
          orElse: () => SecurityLevel.open,
        );
      } catch (_) {
        // Return default on any error
        return SecurityLevel.open;
      }
    }
    
    if (value is int && value >= 0 && value < SecurityLevel.values.length) {
      return SecurityLevel.values[value];
    }
    
    return SecurityLevel.open;
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
  
  @override
  String toString() {
    return 'BusinessCard(name: $name, company: $company, email: $email, phone: $phone)';
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
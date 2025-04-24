import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/business_card.dart';
import '../security/encryption.dart';
import '../security/tamper_detection.dart';

/// Helper class for working with NDEF messages
class NDEFHelper {
  final Encryption _encryption = Encryption();
  final TamperDetection _tamperDetection = TamperDetection();

  // Record type constants
  static const String _uriRecordType = 'U';
  static const String _textRecordType = 'T';
  static const String _businessCardMimeType = 'application/vnd.swahilicard';

  /// Converts business card data to NDEF format
  dynamic convertToNDEF(BusinessCardData data,
      {SecurityCredentials? credentials}) {
    // Create JSON representation of business card
    final Map<String, dynamic> jsonData = data.toJson();

    // Apply security if needed
    if (data.securityLevel != SecurityLevel.open && credentials != null) {
      _applySecurityToJson(jsonData, data.securityLevel, credentials);
    }

    // Create NDEF message
    return _createNdefMessage(jsonData, data);
  }

  /// Converts NDEF data to business card format
  BusinessCardData convertFromNDEF(dynamic ndefData) {
    // Extract JSON data from NDEF message
    final jsonData = _extractJsonFromNdef(ndefData);

    // Create business card from JSON
    return BusinessCardData.fromJson(jsonData);
  }

  /// Gets security level from NDEF data
  SecurityLevel getSecurityLevel(dynamic ndefData) {
    try {
      final jsonData = _extractJsonFromNdef(ndefData);

      if (jsonData.containsKey('securityLevel')) {
        final levelStr = jsonData['securityLevel'];
        return SecurityLevel.values.firstWhere(
          (level) => level.toString().split('.').last == levelStr,
          orElse: () => SecurityLevel.open,
        );
      }

      return SecurityLevel.open;
    } catch (e) {
      return SecurityLevel.open;
    }
  }

  /// Creates an NDEF message from JSON data
  dynamic _createNdefMessage(
      Map<String, dynamic> jsonData, BusinessCardData data) {
    // Convert to JSON string
    final jsonStr = json.encode(jsonData);

    // For cards with social links, you might want to add URI records
    if (data.social.containsKey('website')) {
      // Example of using the URI record type
      final websiteUrl = data.social['website']!;
      final uriRecord = {
        'type': _uriRecordType,
        'uri': websiteUrl,
      };

      // Use text record for open cards, custom mime for secured
      final primaryRecordType = data.securityLevel == SecurityLevel.open
          ? _textRecordType
          : _businessCardMimeType;

      // Add URI record to message
      return {
        'primaryRecord': {'type': primaryRecordType, 'payload': jsonStr},
        'additionalRecords': [uriRecord],
      };
    }

    // For this implementation, we'll just return the JSON string
    // In a real implementation, this would create platform-specific NDEF records
    return jsonStr;
  }

  /// Extracts JSON data from NDEF message
  Map<String, dynamic> _extractJsonFromNdef(dynamic ndefData) {
    if (ndefData is Map<String, dynamic>) {
      // Check if it's our multi-record format
      if (ndefData.containsKey('primaryRecord')) {
        final primaryRecord = ndefData['primaryRecord'];
        if (primaryRecord is Map<String, dynamic> &&
            primaryRecord.containsKey('payload')) {
          return json.decode(primaryRecord['payload']);
        }
        return json.decode(primaryRecord.toString());
      }
      return ndefData;
    }

    if (ndefData is String) {
      return json.decode(ndefData);
    }

    if (ndefData is List<int>) {
      return json.decode(utf8.decode(ndefData));
    }

    throw const FormatException('Unsupported NDEF data format');
  }

  /// Applies security to JSON data
  void _applySecurityToJson(
    Map<String, dynamic> jsonData,
    SecurityLevel securityLevel,
    SecurityCredentials credentials,
  ) {
    // Add security metadata
    jsonData['security'] = {
      'level': securityLevel.index,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add security features based on level
    switch (securityLevel) {
      case SecurityLevel.basic:
        if (credentials.password != null) {
          jsonData['security']['hash'] = _hashPassword(credentials.password!);
        }
        break;

      case SecurityLevel.enhanced:
      case SecurityLevel.premium:
        if (credentials.encryptionKey != null) {
          // Add expiration if provided
          if (credentials.expiration != null) {
            jsonData['security']['expiry'] =
                credentials.expiration!.toIso8601String();
          }

          // For premium security, add signature to detect tampering
          if (securityLevel == SecurityLevel.premium) {
            jsonData['signature'] = _tamperDetection.signData(jsonData);
          }

          // Encrypt sensitive data
          _encryptSensitiveFields(jsonData, credentials.encryptionKey!);
        }
        break;

      case SecurityLevel.open:
      default:
        // No security needed
        break;
    }
  }

  /// Hashes a password for security
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Encrypts sensitive fields in the JSON data
  void _encryptSensitiveFields(Map<String, dynamic> jsonData, String key) {
    // Added const constructor for the set
    const sensitiveFields = <String>{
      'phone',
      'email',
      'custom',
      'social',
    };

    // Extract sensitive data
    final sensitiveData = <String, dynamic>{};
    for (final field in sensitiveFields) {
      if (jsonData.containsKey(field)) {
        sensitiveData[field] = jsonData[field];
        jsonData.remove(field);
      }
    }

    // Only encrypt if there's data to encrypt
    if (sensitiveData.isNotEmpty) {
      // Convert sensitive data to bytes
      final bytes = utf8.encode(json.encode(sensitiveData));

      // Encrypt
      final encrypted = _encryption.encryptData(
        Uint8List.fromList(bytes),
        key,
      );

      // Store encrypted data
      jsonData['encryptedData'] = base64Encode(encrypted);
    }
  }
}

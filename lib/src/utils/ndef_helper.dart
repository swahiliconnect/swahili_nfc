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

  /// Converts business card data to NDEF format
  /// Always returns a String for consistency across platforms
  String convertToNDEF(BusinessCardData data, {SecurityCredentials? credentials}) {
    // Create JSON representation of business card
    final Map<String, dynamic> jsonData = data.toJson();

    // Apply security if needed
    if (data.securityLevel != SecurityLevel.open && credentials != null) {
      _applySecurityToJson(jsonData, data.securityLevel, credentials);
    }

    // Convert to consistent JSON string format
    return json.encode(jsonData);
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

  /// Extracts JSON data from NDEF message with improved error handling
  Map<String, dynamic> _extractJsonFromNdef(dynamic ndefData) {
    try {
      // If it's already a Map with expected fields, return it
      if (ndefData is Map<String, dynamic>) {
        if (ndefData.containsKey('name')) {
          return ndefData;
        }
        
        // Check if it's our multi-record format
        if (ndefData.containsKey('primaryRecord')) {
          final primaryRecord = ndefData['primaryRecord'];
          if (primaryRecord is Map<String, dynamic> && primaryRecord.containsKey('payload')) {
            try {
              final payload = primaryRecord['payload'];
              if (payload is String) {
                return json.decode(payload);
              } else if (payload is Map<String, dynamic>) {
                return payload;
              }
            } catch (e) {
              // Fallback for parsing errors
            }
          }
        }
      }

      // Handle String format
      if (ndefData is String) {
        try {
          // Try to parse as JSON
          final decoded = json.decode(ndefData);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (e) {
          // If not valid JSON, create a minimal card with the string as name
          return {
            'name': ndefData.substring(0, ndefData.length.clamp(0, 50)),
            'cardId': DateTime.now().millisecondsSinceEpoch.toString(),
            'createdAt': DateTime.now().toIso8601String(),
          };
        }
      }

      // Handle byte array format (common from native code)
      if (ndefData is List<int>) {
        try {
          final utf8String = utf8.decode(ndefData);
          try {
            final decoded = json.decode(utf8String);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
          } catch (e) {
            // If not valid JSON, create a minimal card with the string as name
            return {
              'name': utf8String.substring(0, utf8String.length.clamp(0, 50)),
              'cardId': DateTime.now().millisecondsSinceEpoch.toString(),
              'createdAt': DateTime.now().toIso8601String(),
            };
          }
        } catch (e) {
          // If UTF-8 decoding fails, try UTF-16
          try {
            final utf16String = String.fromCharCodes(ndefData);
            try {
              final decoded = json.decode(utf16String);
              if (decoded is Map<String, dynamic>) {
                return decoded;
              }
            } catch (_) {
              // Not valid JSON
            }
          } catch (_) {
            // UTF-16 decoding failed
          }
        }
      }

      // Default fallback if all parsing attempts fail
      return {
        'name': 'Unknown Card',
        'cardId': DateTime.now().millisecondsSinceEpoch.toString(),
        'createdAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      // Global exception handler - return a valid default object
      return {
        'name': 'Error Card',
        'cardId': DateTime.now().millisecondsSinceEpoch.toString(),
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
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
    // Define sensitive fields
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
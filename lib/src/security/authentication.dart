import 'dart:convert';
import 'dart:typed_data';

// Import crypto library for password hashing
import 'package:crypto/crypto.dart';

import '../models/business_card.dart';
import '../utils/error_handler.dart';
import 'encryption.dart';
import 'tamper_detection.dart';

/// Handles authentication and security operations for NFC cards
class Authentication {
  final Encryption _encryption = Encryption();
  final TamperDetection _tamperDetection = TamperDetection();
  
  /// Sets security level for a card
  Future<void> setCardSecurity({
    required SecurityLevel securityLevel,
    required SecurityCredentials credentials,
  }) async {
    // Validation
    if (securityLevel == SecurityLevel.open) {
      return; // No security needed
    }
    
    if (securityLevel == SecurityLevel.basic && credentials.password == null) {
      throw NFCError(
        code: NFCErrorCode.securityError,
        message: 'Password required for basic security level',
      );
    }
    
    if ((securityLevel == SecurityLevel.enhanced || 
         securityLevel == SecurityLevel.premium) && 
        credentials.encryptionKey == null) {
      throw NFCError(
        code: NFCErrorCode.securityError,
        message: 'Encryption key required for enhanced/premium security level',
      );
    }
    
    // Store security credentials (implementation depends on use case)
    // For this package, we assume credentials are stored in card data
  }
  
  /// Verifies credentials for a protected card
  Future<bool> verifyCredentials({
    required dynamic rawData,
    required SecurityCredentials credentials,
  }) async {
    try {
      // Extract security metadata from raw data
      final securityMetadata = _extractSecurityMetadata(rawData);
      
      if (securityMetadata == null) {
        return false;
      }
      
      final securityLevel = SecurityLevel.values[securityMetadata['level'] ?? 0];
      
      // Verify based on security level
      switch (securityLevel) {
        case SecurityLevel.open:
          return true; // No verification needed
          
        case SecurityLevel.basic:
          // Simple password check
          final storedHash = securityMetadata['hash'];
          if (storedHash == null || credentials.password == null) {
            return false;
          }
          
          final providedHash = _hashPassword(credentials.password!);
          return storedHash == providedHash;
          
        case SecurityLevel.enhanced:
        case SecurityLevel.premium:
          // Verify using encryption key
          if (credentials.encryptionKey == null) {
            return false;
          }
          
          // Check if expiration date is valid
          if (securityMetadata['expiry'] != null) {
            final expiry = DateTime.parse(securityMetadata['expiry']);
            if (DateTime.now().isAfter(expiry)) {
              return false; // Expired
            }
          }
          
          // Premium security also checks for tampering
          if (securityLevel == SecurityLevel.premium) {
            final isTampered = await _tamperDetection.detectTampering(rawData);
            if (isTampered) {
              return false;
            }
          }
          
          return true;
          
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Decrypts data with provided credentials
  Future<dynamic> decryptData({
    required dynamic rawData,
    required SecurityCredentials credentials,
  }) async {
    try {
      // Extract security metadata
      final securityMetadata = _extractSecurityMetadata(rawData);
      
      if (securityMetadata == null) {
        return rawData; // No encryption
      }
      
      final securityLevel = SecurityLevel.values[securityMetadata['level'] ?? 0];
      
      if (securityLevel == SecurityLevel.open || 
          securityLevel == SecurityLevel.basic) {
        return rawData; // No encryption
      }
      
      // For enhanced and premium levels, decrypt data
      if (credentials.encryptionKey == null) {
        throw NFCError(
          code: NFCErrorCode.securityError,
          message: 'Encryption key required for decryption',
        );
      }
      
      // Extract encrypted data
      final encryptedData = _extractEncryptedData(rawData);
      
      if (encryptedData == null) {
        return rawData; // No encrypted data found
      }
      
      // Decrypt data
      final decryptedData = _encryption.decryptData(
        encryptedData,
        credentials.encryptionKey!,
      );
      
      // Return decrypted data
      return _replaceEncryptedWithDecrypted(rawData, decryptedData);
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.securityError,
        message: 'Failed to decrypt data: ${e.toString()}',
      );
    }
  }
  
  /// Hashes a password for storage/comparison
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Extracts security metadata from raw data
  Map<String, dynamic>? _extractSecurityMetadata(dynamic rawData) {
    // Implementation depends on data format
    // This is a placeholder implementation
    try {
      if (rawData is Map<String, dynamic> && 
          rawData.containsKey('security')) {
        return rawData['security'];
      }
      
      if (rawData is String) {
        final data = json.decode(rawData);
        if (data is Map<String, dynamic> && 
            data.containsKey('security')) {
          return data['security'];
        }
      }
      
      if (rawData is List<int>) {
        final data = json.decode(utf8.decode(rawData));
        if (data is Map<String, dynamic> && 
            data.containsKey('security')) {
          return data['security'];
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Extracts encrypted data from raw data
  Uint8List? _extractEncryptedData(dynamic rawData) {
    // Implementation depends on data format
    // This is a placeholder implementation
    try {
      if (rawData is Map<String, dynamic> && 
          rawData.containsKey('encryptedData')) {
        final base64Data = rawData['encryptedData'];
        return base64Decode(base64Data);
      }
      
      if (rawData is String) {
        final data = json.decode(rawData);
        if (data is Map<String, dynamic> && 
            data.containsKey('encryptedData')) {
          final base64Data = data['encryptedData'];
          return base64Decode(base64Data);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Replaces encrypted data with decrypted data in the raw data
  dynamic _replaceEncryptedWithDecrypted(dynamic rawData, Uint8List decryptedData) {
    try {
      // Convert decrypted data to JSON
      final decryptedJson = json.decode(utf8.decode(decryptedData));
      
      if (rawData is Map<String, dynamic>) {
        // Create new map with decrypted content
        final result = Map<String, dynamic>.from(rawData);
        result.remove('encryptedData');
        result.addAll(decryptedJson);
        return result;
      }
      
      if (rawData is String) {
        final data = json.decode(rawData);
        if (data is Map<String, dynamic>) {
          final result = Map<String, dynamic>.from(data);
          result.remove('encryptedData');
          result.addAll(decryptedJson);
          return json.encode(result);
        }
      }
      
      return decryptedJson;
    } catch (e) {
      // If decrypted data isn't valid JSON, return as is
      return decryptedData;
    }
  }
}


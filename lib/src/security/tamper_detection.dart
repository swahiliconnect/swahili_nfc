import 'dart:convert';
// Removed unused import: dart:typed_data

import 'package:crypto/crypto.dart';

/// Handles tamper detection for NFC cards
class TamperDetection {
  /// Detects if card data has been tampered with
  Future<bool> detectTampering(dynamic rawData) async {
    try {
      // Extract signature and data
      final extracted = _extractSignatureAndData(rawData);

      if (extracted == null) {
        return true; // No signature found, consider tampered
      }

      final signature = extracted['signature'] as String;
      final data = extracted['data'];

      // Verify signature
      return !_verifySignature(data, signature);
    } catch (e) {
      return true; // Any error, consider tampered
    }
  }

  /// Signs data to prevent tampering
  String signData(dynamic data) {
    final jsonData = data is String ? data : json.encode(data);
    final dataBytes = utf8.encode(jsonData);

    // In a real implementation, this would use asymmetric cryptography
    // For this example, we'll use a simple HMAC with a fixed key
    final key = utf8.encode('SwahiliNFC_TamperDetection_Key');
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(dataBytes);

    return digest.toString();
  }

  /// Extracts signature and data from raw data
  Map<String, dynamic>? _extractSignatureAndData(dynamic rawData) {
    try {
      if (rawData is Map<String, dynamic> && rawData.containsKey('signature')) {
        final signature = rawData['signature'];
        final dataCopy = Map<String, dynamic>.from(rawData);
        dataCopy.remove('signature');
        return {
          'signature': signature,
          'data': dataCopy,
        };
      }

      if (rawData is String) {
        final decoded = json.decode(rawData);
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('signature')) {
          final signature = decoded['signature'];
          final dataCopy = Map<String, dynamic>.from(decoded);
          dataCopy.remove('signature');
          return {
            'signature': signature,
            'data': dataCopy,
          };
        }
      }

      if (rawData is List<int>) {
        final decoded = json.decode(utf8.decode(rawData));
        if (decoded is Map<String, dynamic> &&
            decoded.containsKey('signature')) {
          final signature = decoded['signature'];
          final dataCopy = Map<String, dynamic>.from(decoded);
          dataCopy.remove('signature');
          return {
            'signature': signature,
            'data': dataCopy,
          };
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verifies signature against data
  bool _verifySignature(dynamic data, String signature) {
    try {
      final jsonData = data is String ? data : json.encode(data);
      final dataBytes = utf8.encode(jsonData);

      // Same key as in signData
      final key = utf8.encode('SwahiliNFC_TamperDetection_Key');
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(dataBytes);

      return digest.toString() == signature;
    } catch (e) {
      return false;
    }
  }
}

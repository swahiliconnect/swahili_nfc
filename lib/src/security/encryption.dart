import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Handles encryption and decryption of NFC data
class Encryption {
  // Key length in bytes (256 bits)
  static const int _keyLength = 32;
  
  /// Encrypts data using AES-256
  Uint8List encryptData(Uint8List data, String key) {
    // Derive 256-bit key from provided string key
    final derivedKey = _deriveKey(key, _keyLength);
    
    // Generate random IV
    final iv = encrypt.IV.fromSecureRandom(16);
    
    // Create encrypter with derived key
    final encrypter = encrypt.Encrypter(encrypt.AES(
      encrypt.Key(derivedKey),
      mode: encrypt.AESMode.cbc,
      padding: 'PKCS7',
    ));
    
    // Encrypt data
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    // Combine IV and encrypted data
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setRange(0, iv.bytes.length, iv.bytes);
    result.setRange(iv.bytes.length, result.length, encrypted.bytes);
    
    return result;
  }
  
  /// Decrypts encrypted data using AES-256
  Uint8List decryptData(Uint8List encryptedData, String key) {
    // Derive 256-bit key from provided string key
    final derivedKey = _deriveKey(key, _keyLength);
    
    // Extract IV from first 16 bytes
    final iv = encrypt.IV(Uint8List.fromList(
      encryptedData.sublist(0, 16),
    ));
    
    // Extract encrypted data excluding IV
    final dataToDecrypt = encrypt.Encrypted(Uint8List.fromList(
      encryptedData.sublist(16),
    ));
    
    // Create encrypter with derived key
    final encrypter = encrypt.Encrypter(encrypt.AES(
      encrypt.Key(derivedKey),
      mode: encrypt.AESMode.cbc,
      padding: 'PKCS7',
    ));
    
    // Decrypt data
    return Uint8List.fromList(encrypter.decryptBytes(dataToDecrypt, iv: iv));
  }
  
  /// Generates a random encryption key
  String generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  /// Derives a fixed-length key from a string using PBKDF2
  Uint8List _deriveKey(String key, int length) {
    // Use a fixed salt for deterministic results
    final salt = utf8.encode('SwahiliNFC');
    
    // Derive key using PBKDF2
    final keyBytes = utf8.encode(key);
    
    // Calculate PBKDF2 using HMAC-SHA256
    var derivedKey = _pbkdf2(
      keyBytes,
      salt,
      10000, // iterations
      length,
    );
    
    return derivedKey;
  }
  
  /// PBKDF2 implementation using HMAC-SHA256
  Uint8List _pbkdf2(List<int> key, List<int> salt, int iterations, int length) {
    var result = Uint8List(length);
    var block = 1;
    var offset = 0;
    
    while (offset < length) {
      // Calculate block
      var currentBlock = _calculateBlock(key, salt, iterations, block);
      
      // Copy to result
      var toCopy = min(length - offset, currentBlock.length);
      result.setRange(offset, offset + toCopy, currentBlock);
      
      offset += toCopy;
      block++;
    }
    
    return result;
  }
  
  /// Calculates a single block for PBKDF2
  Uint8List _calculateBlock(List<int> key, List<int> salt, int iterations, int blockIndex) {
    var blockData = <int>[];
    blockData.addAll(salt);
    blockData.addAll(_intToBytes(blockIndex));
    
    var result = Hmac(sha256, key).convert(blockData).bytes;
    var block = Uint8List.fromList(result);
    
    var temp = Uint8List.fromList(block);
    
    for (var i = 1; i < iterations; i++) {
      temp = Uint8List.fromList(Hmac(sha256, key).convert(temp).bytes);
      
      for (var j = 0; j < block.length; j++) {
        block[j] ^= temp[j];
      }
    }
    
    return block;
  }
  
  /// Converts an integer to 4 bytes (big-endian)
  List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }
}
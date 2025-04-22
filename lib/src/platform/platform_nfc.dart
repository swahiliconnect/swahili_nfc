import 'dart:async';
import 'dart:io';

import 'android_nfc.dart';
import 'ios_nfc.dart';
import '../utils/error_handler.dart';

/// Abstract class for platform-specific NFC implementations
abstract class PlatformNFC {
  /// Gets the platform-specific NFC implementation instance
  static PlatformNFC getInstance() {
    if (Platform.isAndroid) {
      return AndroidNFC();
    } else if (Platform.isIOS) {
      return IOSNFC();
    } else {
      throw NFCError(
        code: NFCErrorCode.platformNotSupported,
        message: 'Platform ${Platform.operatingSystem} is not supported',
      );
    }
  }
  
  /// Checks if NFC is available on the device
  Future<bool> isAvailable();
  
  /// Starts an NFC session
  Future<dynamic> startSession({
    required bool isReading,
    required bool isWriting,
  });
  
  /// Stops the current NFC session
  Future<void> stopSession();
  
  /// Reads data from an NFC tag
  Future<dynamic> readTag();
  
  /// Writes data to an NFC tag
  Future<void> writeTag(dynamic data);
  
  /// Starts continuous reading for NFC tags
  void startContinuousReading({
    required Function(dynamic) onTagDetected,
  });
}
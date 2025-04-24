import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_nfc.dart';
import '../utils/error_handler.dart';

/// iOS-specific NFC implementation
class IOSNFC implements PlatformNFC {
  static const MethodChannel _channel =
      MethodChannel('com.swahilicard.nfc/ios');

  bool _isSessionActive = false;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable') ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<dynamic> startSession({
    required bool isReading,
    required bool isWriting,
  }) async {
    if (_isSessionActive) {
      await stopSession();
    }

    try {
      final result = await _channel.invokeMethod('startSession', {
        'isReading': isReading,
        'isWriting': isWriting,
        'alertMessage': isReading
            ? 'Hold your iPhone near an NFC business card'
            : 'Hold your iPhone near an NFC card to write data',
      });

      _isSessionActive = true;
      return result;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'Failed to start iOS NFC session: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> stopSession() async {
    if (!_isSessionActive) {
      return;
    }

    try {
      await _channel.invokeMethod('stopSession');
      _isSessionActive = false;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'Failed to stop iOS NFC session: ${e.toString()}',
      );
    }
  }

  @override
  Future<dynamic> readTag() async {
    if (!_isSessionActive) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'No active session for reading',
      );
    }

    try {
      // iOS handles tag reading in the session automatically
      // This call just returns the data from the current session
      return await _channel.invokeMethod('getTagData');
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to read iOS NFC tag: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> writeTag(dynamic data) async {
    if (!_isSessionActive) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'No active session for writing',
      );
    }

    try {
      await _channel.invokeMethod('writeTag', {
        'data': data,
      });
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.writeError,
        message: 'Failed to write iOS NFC tag: ${e.toString()}',
      );
    }
  }

  @override
  void startContinuousReading({
    required Function(dynamic) onTagDetected,
  }) async {
    // iOS doesn't support true background scanning
    // Instead, we'll simulate it by starting a new session each time

    try {
      // Set up event channel for tag detection
      const EventChannel tagChannel =
          EventChannel('com.swahilicard.nfc/ios/tags');

      tagChannel.receiveBroadcastStream().listen(
        (dynamic tagData) {
          onTagDetected(tagData);

          // Restart session after a brief delay
          Future.delayed(const Duration(milliseconds: 500), () async {
            await stopSession();
            await startSession(isReading: true, isWriting: false);
          });
        },
        onError: (dynamic error) {
          // Removed print statement, using logger instead
          _logError('Error in continuous reading: $error');
        },
      );

      // Start initial session
      await startSession(isReading: true, isWriting: false);
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to start continuous reading: ${e.toString()}',
      );
    }
  }

  // Logger method instead of print
  void _logError(String message) {
    // In a production app, this would use a proper logging framework
    // Intentionally left empty to avoid print statements
  }
}

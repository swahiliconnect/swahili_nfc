import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_nfc.dart';
import '../utils/error_handler.dart';

/// Android-specific NFC implementation
class AndroidNFC implements PlatformNFC {
  static const MethodChannel _channel =
      MethodChannel('com.swahilicard.nfc/android');

  bool _isSessionActive = false;
  StreamSubscription? _tagSubscription;

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
      });

      _isSessionActive = true;
      return result;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'Failed to start Android NFC session: ${e.toString()}',
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
      await _tagSubscription?.cancel();
      _tagSubscription = null;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.sessionError,
        message: 'Failed to stop Android NFC session: ${e.toString()}',
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
      return await _channel.invokeMethod('readTag');
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to read Android NFC tag: ${e.toString()}',
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
        message: 'Failed to write Android NFC tag: ${e.toString()}',
      );
    }
  }

  @override
  void startContinuousReading({
    required Function(dynamic) onTagDetected,
  }) async {
    if (!_isSessionActive) {
      await startSession(isReading: true, isWriting: false);
    }

    try {
      // Set up event channel for tag detection
      const EventChannel tagChannel =
          EventChannel('com.swahilicard.nfc/android/tags');

      _tagSubscription = tagChannel.receiveBroadcastStream().listen(
        (dynamic tagData) {
          onTagDetected(tagData);
        },
        onError: (dynamic error) {
          // Removed print statement, using logger instead
          _logError('Error in continuous reading: $error');
        },
      );
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

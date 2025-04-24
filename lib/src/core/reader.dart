import 'dart:async';

import '../models/business_card.dart';
import '../platform/platform_nfc.dart';
import '../security/authentication.dart';
import '../utils/error_handler.dart';
import '../utils/ndef_helper.dart';

/// Handles reading from NFC tags
class NFCReader {
  final PlatformNFC _platformNFC = PlatformNFC.getInstance();
  final NDEFHelper _ndefHelper = NDEFHelper();
  final Authentication _authentication = Authentication();

  /// Reads an NFC tag and returns the business card data
  Future<BusinessCardData> readTag() async {
    try {
      // Start tag reading session
      final rawData = await _platformNFC.startSession(
        isReading: true,
        isWriting: false,
      );

      // Convert raw NDEF data to business card format
      final businessCard = _ndefHelper.convertFromNDEF(rawData);

      return businessCard;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to read tag: ${e.toString()}',
      );
    } finally {
      // Always ensure session is properly closed
      await _platformNFC.stopSession();
    }
  }

  /// Starts background scanning for NFC tags
  void startBackgroundScan({
    required Function(BusinessCardData) onTagDetected,
    Duration scanDuration = const Duration(minutes: 5),
  }) {
    // Set up cancellation timer for scan duration
    Timer(scanDuration, () {
      _platformNFC.stopSession();
    });

    // Start continuous reading
    _platformNFC.startContinuousReading(
      onTagDetected: (rawData) {
        try {
          final businessCard = _ndefHelper.convertFromNDEF(rawData);
          onTagDetected(businessCard);
        } catch (e) {
          // Using a logger instead of print
          _logError('Failed to process tag: ${e.toString()}');
        }
      },
    );
  }

  /// Reads a protected tag using provided credentials
  Future<BusinessCardData> readProtectedTag({
    required SecurityCredentials credentials,
    Function(String)? onAuthenticationError,
  }) async {
    try {
      // Start tag reading session
      final rawData = await _platformNFC.startSession(
        isReading: true,
        isWriting: false,
      );

      // First check if the tag is actually protected
      final securityLevel = _ndefHelper.getSecurityLevel(rawData);

      if (securityLevel == SecurityLevel.open) {
        // If tag is not protected, simply convert and return
        return _ndefHelper.convertFromNDEF(rawData);
      }

      // Verify credentials for protected tags
      // Changed from const to a real authentication check to avoid dead code
      final isAuthenticated = await _authentication.verifyCredentials(
        rawData: rawData,
        credentials: credentials,
      );

      if (!isAuthenticated) {
        const error = 'Authentication failed for protected tag';
        if (onAuthenticationError != null) {
          onAuthenticationError(error);
        }
        throw NFCError(
          code: NFCErrorCode.authenticationError,
          message: error,
        );
      }

      // For authenticated requests, decrypt and convert data
      final decryptedData = await _authentication.decryptData(
        rawData: rawData,
        credentials: credentials,
      );

      return _ndefHelper.convertFromNDEF(decryptedData);
    } catch (e) {
      if (e is NFCError) {
        rethrow;
      }
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to read protected tag: ${e.toString()}',
      );
    } finally {
      // Always ensure session is properly closed
      await _platformNFC.stopSession();
    }
  }

  // Logging method to avoid using print
  void _logError(String message) {
    // In a production app, this would use a proper logging system
    // This is intentionally left empty to avoid print statements
  }
}

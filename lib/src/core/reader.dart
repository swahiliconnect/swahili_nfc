import 'dart:async';
import 'dart:developer' as developer;

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
  
  // Debug mode for logging
  bool _debugMode = false;

  /// Reads an NFC tag and returns the business card data
  Future<BusinessCardData> readTag() async {
    try {
      _debugLog('Starting tag reading session');
      
      // Start tag reading session
      final rawData = await _platformNFC.startSession(
        isReading: true,
        isWriting: false,
      );
      
      _debugLog('Received raw data: ${rawData.toString().substring(0, rawData.toString().length > 100 ? 100 : rawData.toString().length)}...');

      // Convert raw NDEF data to business card format
      final businessCard = _ndefHelper.convertFromNDEF(rawData);
      
      _debugLog('Converted to BusinessCard: ${businessCard.name}, ${businessCard.company}, ${businessCard.email}, ${businessCard.phone}');

      return businessCard;
    } catch (e) {
      _debugLog('Error reading tag: ${e.toString()}');
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to read tag: ${e.toString()}',
      );
    } finally {
      // Always ensure session is properly closed
      await _platformNFC.stopSession();
      _debugLog('Tag reading session stopped');
    }
  }

  /// Starts background scanning for NFC tags
  void startBackgroundScan({
    required Function(BusinessCardData) onTagDetected,
    Duration scanDuration = const Duration(minutes: 5),
  }) {
    _debugLog('Starting background scan with duration: ${scanDuration.inSeconds} seconds');
    
    // Set up cancellation timer for scan duration
    Timer(scanDuration, () {
      _platformNFC.stopSession();
      _debugLog('Background scan stopped due to timeout');
    });

    // Start continuous reading
    _platformNFC.startContinuousReading(
      onTagDetected: (rawData) {
        try {
          _debugLog('Background scan detected tag');
          final businessCard = _ndefHelper.convertFromNDEF(rawData);
          _debugLog('Converted to BusinessCard: ${businessCard.name}');
          onTagDetected(businessCard);
        } catch (e) {
          _debugLog('Failed to process tag in background scan: ${e.toString()}');
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
      _debugLog('Starting protected tag reading session');
      
      // Start tag reading session
      final rawData = await _platformNFC.startSession(
        isReading: true,
        isWriting: false,
      );
      
      _debugLog('Received raw data from protected tag');

      // First check if the tag is actually protected
      final securityLevel = _ndefHelper.getSecurityLevel(rawData);
      _debugLog('Detected security level: $securityLevel');

      if (securityLevel == SecurityLevel.open) {
        _debugLog('Tag is not protected, converting directly');
        // If tag is not protected, simply convert and return
        return _ndefHelper.convertFromNDEF(rawData);
      }

      // Verify credentials for protected tags
      _debugLog('Verifying credentials for protected tag');
      final isAuthenticated = await _authentication.verifyCredentials(
        rawData: rawData,
        credentials: credentials,
      );

      if (!isAuthenticated) {
        const error = 'Authentication failed for protected tag';
        _debugLog(error);
        if (onAuthenticationError != null) {
          onAuthenticationError(error);
        }
        throw NFCError(
          code: NFCErrorCode.authenticationError,
          message: error,
        );
      }

      // For authenticated requests, decrypt and convert data
      _debugLog('Authentication successful, decrypting data');
      final decryptedData = await _authentication.decryptData(
        rawData: rawData,
        credentials: credentials,
      );

      final card = _ndefHelper.convertFromNDEF(decryptedData);
      _debugLog('Successfully read protected card: ${card.name}');
      return card;
    } catch (e) {
      _debugLog('Error reading protected tag: ${e.toString()}');
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
      _debugLog('Protected tag reading session stopped');
    }
  }
  
  /// Gets the raw data from a tag for debugging purposes
  Future<dynamic> dumpRawTagData() async {
    try {
      _debugLog('Starting raw tag data dump');
      
      // Start tag reading session
      final rawData = await _platformNFC.startSession(
        isReading: true,
        isWriting: false,
      );
      
      _debugLog('Received raw data: $rawData');
      return rawData;
    } catch (e) {
      _debugLog('Error dumping raw tag data: ${e.toString()}');
      throw NFCError(
        code: NFCErrorCode.readError,
        message: 'Failed to dump tag data: ${e.toString()}',
      );
    } finally {
      // Always ensure session is properly closed
      await _platformNFC.stopSession();
    }
  }
  
  /// Set debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    _debugLog('Debug mode ${enabled ? 'enabled' : 'disabled'}');
  }

  // Debug logging method
  void _debugLog(String message) {
    if (_debugMode) {
      developer.log(message, name: 'SwahiliNFC.Reader');
    }
  }
}
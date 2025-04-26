import 'dart:developer' as developer;

import '../models/business_card.dart';
import '../platform/platform_nfc.dart';
import '../security/authentication.dart';
import '../security/encryption.dart';
import '../utils/error_handler.dart';
import '../utils/ndef_helper.dart';

/// Handles writing to NFC tags
class NFCWriter {
  final PlatformNFC _platformNFC = PlatformNFC.getInstance();
  final NDEFHelper _ndefHelper = NDEFHelper();
  final Authentication _authentication = Authentication();
  final Encryption _encryption = Encryption();
  
  // Debug mode for logging
  bool _debugMode = true;

  /// Writes business card data to an NFC tag
  Future<bool> writeTag({
    required BusinessCardData data,
    bool verifyAfterWrite = true,
  }) async {
    try {
      // Convert business card data to NDEF format
      // This should always return a String for consistency
      final ndefData = _ndefHelper.convertToNDEF(data);
      
      // Debug log the data being written
      _debugLog('Writing card data: ${data.name}, ${data.email}, ${data.phone}');
      _debugLog('NDEF data (first 100 chars): ${ndefData.substring(0, ndefData.length > 100 ? 100 : ndefData.length)}...');

      // Start tag writing session
      await _platformNFC.startSession(
        isReading: false,
        isWriting: true,
      );

      // Write data to tag
      await _platformNFC.writeTag(ndefData);
      _debugLog('Write operation completed');

      // Verify data was written correctly if requested
      if (verifyAfterWrite) {
        _debugLog('Starting verification...');
        await _platformNFC.stopSession();
        
        // Wait a brief moment to ensure the tag is ready for reading
        await Future.delayed(const Duration(milliseconds: 500));

        // Start a new reading session
        await _platformNFC.startSession(
          isReading: true,
          isWriting: false,
        );

        final readData = await _platformNFC.readTag();
        _debugLog('Read back data: ${readData is String ? readData.substring(0, readData.length > 100 ? 100 : readData.length) : "non-string data"}');
        
        final readCard = _ndefHelper.convertFromNDEF(readData);
        _debugLog('Converted read data to card: ${readCard.name}, ${readCard.email}, ${readCard.phone}');

        // Compare written data with read data
        // Check essential fields to make sure the card was properly written
        bool nameMatches = readCard.name == data.name;
        bool idMatches = readCard.cardId == data.cardId;
        bool securityMatches = readCard.securityLevel == data.securityLevel;
        
        _debugLog('Verification results:');
        _debugLog(' - Name matches: $nameMatches (${readCard.name} vs ${data.name})');
        _debugLog(' - ID matches: $idMatches (${readCard.cardId} vs ${data.cardId})');
        _debugLog(' - Security level matches: $securityMatches');
        
        if (!nameMatches || !idMatches || !securityMatches) {
          throw NFCError(
            code: NFCErrorCode.verificationError,
            message: 'Verification failed: Tag data does not match written data',
          );
        }
        
        // Also verify contact details if present
        if (data.email != null) {
          _debugLog(' - Email check: ${readCard.email} vs ${data.email}');
        }
        if (data.phone != null) {
          _debugLog(' - Phone check: ${readCard.phone} vs ${data.phone}');
        }
        
        _debugLog('Verification successful');
      }

      return true;
    } catch (e) {
      _debugLog('Error in writeTag: ${e.toString()}');
      if (e is NFCError) {
        rethrow;
      }
      throw NFCError(
        code: NFCErrorCode.writeError,
        message: 'Failed to write tag: ${e.toString()}',
      );
    } finally {
      // Always ensure session is properly closed
      await _platformNFC.stopSession();
    }
  }

  /// Starts the card activation process
  void startCardActivation({
    required BusinessCardData cardData,
    required SecurityOptions security,
    required NFCDeviceType deviceType,
    Function()? onActivationStarted,
    Function(double)? onProgress,
    Function(String)? onActivationComplete,
    Function(NFCError)? onError,
  }) async {
    try {
      _debugLog('Starting card activation process');
      
      if (onActivationStarted != null) {
        onActivationStarted();
      }

      // Step 1: Apply security if needed (25%)
      if (security.level != SecurityLevel.open) {
        _debugLog('Applying security level: ${security.level}');
        
        // Apply encryption based on security level
        if (security.level == SecurityLevel.enhanced ||
            security.level == SecurityLevel.premium) {
          // Generate encryption key if not provided
          final encryptionKey =
              security.password ?? _encryption.generateRandomKey();

          _debugLog('Setting up encryption with security level ${security.level}');
          await _authentication.setCardSecurity(
            securityLevel: security.level,
            credentials: SecurityCredentials(
              password: security.password,
              encryptionKey: encryptionKey,
              expiration: security.expiry,
            ),
          );
        } else if (security.level == SecurityLevel.basic) {
          _debugLog('Setting up basic security with password');
          await _authentication.setCardSecurity(
            securityLevel: security.level,
            credentials: SecurityCredentials(
              password: security.password,
            ),
          );
        }

        if (onProgress != null) {
          onProgress(0.25);
        }
      } else {
        _debugLog('Using open security level (no protection)');
      }

      // Step 2: Prepare card data (50%)
      _debugLog('Preparing card data');
      BusinessCardData preparedCardData = BusinessCardData(
        name: cardData.name,
        company: cardData.company,
        position: cardData.position,
        email: cardData.email,
        phone: cardData.phone,
        social: cardData.social,
        custom: cardData.custom,
        profileImage: cardData.profileImage,
        cardType: cardData.cardType,
        securityLevel: security.level,
        isTemporary: cardData.isTemporary,
      );

      if (onProgress != null) {
        onProgress(0.5);
      }

      // Step 3: Write to card (75%)
      _debugLog('Writing data to card');
      final success = await writeTag(
        data: preparedCardData,
        verifyAfterWrite: true,
      );

      if (!success) {
        throw NFCError(
          code: NFCErrorCode.activationError,
          message: 'Failed to write data during activation',
        );
      }

      if (onProgress != null) {
        onProgress(0.75);
      }

      // Step 4: Complete activation (100%)
      _debugLog('Card activation completed successfully');
      if (onProgress != null) {
        onProgress(1.0);
      }

      if (onActivationComplete != null) {
        onActivationComplete(preparedCardData.cardId);
      }
    } catch (e) {
      _debugLog('Error in card activation: ${e.toString()}');
      final error = e is NFCError
          ? e
          : NFCError(
              code: NFCErrorCode.activationError,
              message: 'Card activation failed: ${e.toString()}',
            );

      if (onError != null) {
        onError(error);
      }
    }
  }
  
  /// Set debug mode
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }
  
  /// Debug logging helper
  void _debugLog(String message) {
    if (_debugMode) {
      developer.log(message, name: 'SwahiliNFC.Writer');
    }
  }
}
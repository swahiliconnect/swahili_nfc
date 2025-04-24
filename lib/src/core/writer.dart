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

  /// Writes business card data to an NFC tag
  Future<bool> writeTag({
    required BusinessCardData data,
    bool verifyAfterWrite = true,
  }) async {
    try {
      // Convert business card data to NDEF format
      final ndefData = _ndefHelper.convertToNDEF(data);

      // Start tag writing session
      await _platformNFC.startSession(
        isReading: false,
        isWriting: true,
      );

      // Write data to tag
      await _platformNFC.writeTag(ndefData);

      // Verify data was written correctly if requested
      if (verifyAfterWrite) {
        await _platformNFC.stopSession();

        // Start a new reading session
        await _platformNFC.startSession(
          isReading: true,
          isWriting: false,
        );

        final readData = await _platformNFC.readTag();
        final readCard = _ndefHelper.convertFromNDEF(readData);

        // Compare written data with read data
        if (readCard.cardId != data.cardId) {
          throw NFCError(
            code: NFCErrorCode.verificationError,
            message:
                'Verification failed: Tag data does not match written data',
          );
        }
      }

      return true;
    } catch (e) {
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
      if (onActivationStarted != null) {
        onActivationStarted();
      }

      // Step 1: Apply security if needed (25%)
      if (security.level != SecurityLevel.open) {
        // Apply encryption based on security level
        if (security.level == SecurityLevel.enhanced ||
            security.level == SecurityLevel.premium) {
          // Generate encryption key if not provided
          final encryptionKey =
              security.password ?? _encryption.generateRandomKey();

          await _authentication.setCardSecurity(
            securityLevel: security.level,
            credentials: SecurityCredentials(
              password: security.password,
              encryptionKey: encryptionKey,
              expiration: security.expiry,
            ),
          );
        }

        if (onProgress != null) {
          onProgress(0.25);
        }
      }

      // Step 2: Prepare card data (50%)
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
      if (onProgress != null) {
        onProgress(1.0);
      }

      if (onActivationComplete != null) {
        onActivationComplete(preparedCardData.cardId);
      }
    } catch (e) {
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
}

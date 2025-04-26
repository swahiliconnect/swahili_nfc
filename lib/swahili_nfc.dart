library swahili_nfc;

// Core exports
export 'src/core/reader.dart';
export 'src/core/writer.dart';
export 'src/core/session_manager.dart';

// Model exports
export 'src/models/business_card.dart';
export 'src/models/device_info.dart';
export 'src/models/scan_record.dart';

// Security exports
export 'src/security/encryption.dart';
export 'src/security/authentication.dart';
export 'src/security/tamper_detection.dart';

// Utility exports
export 'src/utils/ndef_helper.dart';
export 'src/utils/error_handler.dart';
export 'src/utils/analytics.dart';

// Main SwahiliNFC class
import 'dart:async';
import 'dart:developer' as developer;

import 'src/core/reader.dart';
import 'src/core/writer.dart';
import 'src/core/session_manager.dart';
import 'src/models/business_card.dart';
import 'src/models/scan_record.dart';
import 'src/security/encryption.dart';
import 'src/security/authentication.dart';
import 'src/utils/error_handler.dart';
import 'src/utils/analytics.dart';

/// The main class for SwahiliNFC operations.
class SwahiliNFC {
  static final _reader = NFCReader();
  static final _writer = NFCWriter();
  static final _sessionManager = SessionManager();
  static final _encryption = Encryption();
  static final _authentication = Authentication();
  static final _analytics = Analytics();
  
  // Debug settings
  static bool _debugLogging = false;
  static int _logLevel = 1; // 0=none, 1=errors, 2=warnings, 3=info, 4=verbose

  /// Checks if NFC is available on the device.
  static Future<bool> isAvailable() async {
    try {
      final result = await _sessionManager.isNFCAvailable();
      _log('NFC available: $result', level: 3);
      return result;
    } catch (e) {
      _log('Error checking NFC availability: $e', level: 1);
      return false;
    }
  }

  /// Reads an NFC tag and returns the business card data.
  static Future<BusinessCardData> readTag() async {
    _log('Starting NFC tag read operation', level: 3);
    try {
      final result = await _reader.readTag();
      _log('Successfully read card: ${result.name}', level: 3);
      return result;
    } catch (e) {
      _log('Error reading NFC tag: $e', level: 1);
      rethrow;
    }
  }

  /// Starts background scanning for NFC tags.
  static void startBackgroundScan({
    required Function(BusinessCardData) onTagDetected,
    Duration scanDuration = const Duration(minutes: 5),
  }) {
    _log('Starting background NFC scanning for ${scanDuration.inSeconds} seconds', level: 3);
    _reader.startBackgroundScan(
      onTagDetected: (data) {
        _log('Background scan detected card: ${data.name}', level: 3);
        onTagDetected(data);
      },
      scanDuration: scanDuration,
    );
  }

  /// Writes business card data to an NFC tag.
  static Future<bool> writeTag({
    required BusinessCardData data,
    bool verifyAfterWrite = true,
  }) async {
    _log('Starting NFC tag write operation for card: ${data.name}', level: 3);
    try {
      final result = await _writer.writeTag(
        data: data,
        verifyAfterWrite: verifyAfterWrite,
      );
      _log('Write operation completed successfully: $result', level: 3);
      return result;
    } catch (e) {
      _log('Error writing to NFC tag: $e', level: 1);
      rethrow;
    }
  }

  /// Sets security level for a card.
  static Future<void> setCardSecurity({
    required SecurityLevel securityLevel,
    required SecurityCredentials credentials,
  }) async {
    _log('Setting card security level: $securityLevel', level: 3);
    try {
      await _authentication.setCardSecurity(
        securityLevel: securityLevel,
        credentials: credentials,
      );
      _log('Security level set successfully', level: 3);
    } catch (e) {
      _log('Error setting card security: $e', level: 1);
      rethrow;
    }
  }

  /// Reads a protected NFC tag using provided credentials.
  static Future<BusinessCardData> readProtectedTag({
    required SecurityCredentials credentials,
    Function(String)? onAuthenticationError,
  }) async {
    _log('Reading protected NFC tag', level: 3);
    try {
      final result = await _reader.readProtectedTag(
        credentials: credentials,
        onAuthenticationError: (error) {
          _log('Authentication error: $error', level: 1);
          if (onAuthenticationError != null) {
            onAuthenticationError(error);
          }
        },
      );
      _log('Successfully read protected card: ${result.name}', level: 3);
      return result;
    } catch (e) {
      _log('Error reading protected NFC tag: $e', level: 1);
      rethrow;
    }
  }

  /// Gets list of active cards.
  static Future<List<BusinessCardData>> getActiveCards() async {
    _log('Getting active cards', level: 3);
    try {
      final cards = await _sessionManager.getActiveCards();
      _log('Found ${cards.length} active cards', level: 3);
      return cards;
    } catch (e) {
      _log('Error getting active cards: $e', level: 1);
      rethrow;
    }
  }

  /// Deactivates a specific card by ID.
  static Future<void> deactivateCard({
    required String cardId,
  }) async {
    _log('Deactivating card: $cardId', level: 3);
    try {
      await _sessionManager.deactivateCard(cardId: cardId);
      _log('Card deactivated successfully', level: 3);
    } catch (e) {
      _log('Error deactivating card: $e', level: 1);
      rethrow;
    }
  }

  /// Activates a new NFC card/device.
  static Future<String> activateNewCard({
    required NFCDeviceType deviceType,
    required String deviceName,
  }) async {
    _log('Activating new card of type: $deviceType, name: $deviceName', level: 3);
    try {
      final cardId = await _sessionManager.activateNewCard(
        deviceType: deviceType,
        deviceName: deviceName,
      );
      _log('Card activated successfully with ID: $cardId', level: 3);
      return cardId;
    } catch (e) {
      _log('Error activating new card: $e', level: 1);
      rethrow;
    }
  }

  /// Enables analytics collection.
  static void enableAnalytics({
    required AnalyticsConfig analyticsConfig,
  }) {
    _log('Enabling analytics with config: $analyticsConfig', level: 3);
    _analytics.enableAnalytics(analyticsConfig: analyticsConfig);
  }

  /// Gets scan history for a specific card.
  static Future<List<ScanRecord>> getCardScanHistory({
    required String cardId,
  }) async {
    _log('Getting scan history for card: $cardId', level: 3);
    try {
      final history = await _analytics.getCardScanHistory(cardId: cardId);
      _log('Found ${history.length} scan records', level: 3);
      return history;
    } catch (e) {
      _log('Error getting card scan history: $e', level: 1);
      rethrow;
    }
  }

  /// Enables offline mode.
  static void enableOfflineMode({
    int cacheSize = 100,
    bool syncWhenOnline = true,
  }) {
    _log('Enabling offline mode with cache size: $cacheSize', level: 3);
    _sessionManager.enableOfflineMode(
      cacheSize: cacheSize,
      syncWhenOnline: syncWhenOnline,
    );
  }

  /// Forces sync of offline data.
  static Future<void> syncOfflineData() async {
    _log('Syncing offline data', level: 3);
    try {
      await _sessionManager.syncOfflineData();
      _log('Offline data synced successfully', level: 3);
    } catch (e) {
      _log('Error syncing offline data: $e', level: 1);
      rethrow;
    }
  }

  /// Configures package for SwahiliCard integration.
  static void configureForSwahiliCard({
    required String baseUrl,
    String? apiKey,
  }) {
    _log('Configuring for SwahiliCard with baseUrl: $baseUrl', level: 3);
    _sessionManager.configureForSwahiliCard(
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
  }

  /// Generates a SwahiliCard compatible URL.
  static String generateCardUrl({
    required String userId,
    required String cardId,
    bool isSecure = true,
  }) {
    try {
      final url = _sessionManager.generateCardUrl(
        userId: userId,
        cardId: cardId,
        isSecure: isSecure,
      );
      _log('Generated URL: $url', level: 3);
      return url;
    } catch (e) {
      _log('Error generating card URL: $e', level: 1);
      rethrow;
    }
  }

  /// Generates a random encryption key.
  static String generateRandomKey() {
    final key = _encryption.generateRandomKey();
    _log('Generated random encryption key', level: 4);
    return key;
  }

  /// Starts the card activation process.
  static void startCardActivation({
    required BusinessCardData cardData,
    required SecurityOptions security,
    required NFCDeviceType deviceType,
    Function()? onActivationStarted,
    Function(double)? onProgress,
    Function(String)? onActivationComplete,
    Function(NFCError)? onError,
  }) {
    _log('Starting card activation process for ${cardData.name}', level: 3);
    _writer.startCardActivation(
      cardData: cardData,
      security: security,
      deviceType: deviceType,
      onActivationStarted: () {
        _log('Card activation started', level: 3);
        if (onActivationStarted != null) {
          onActivationStarted();
        }
      },
      onProgress: (progress) {
        _log('Activation progress: ${(progress * 100).toInt()}%', level: 4);
        if (onProgress != null) {
          onProgress(progress);
        }
      },
      onActivationComplete: (cardId) {
        _log('Card activation completed with ID: $cardId', level: 3);
        if (onActivationComplete != null) {
          onActivationComplete(cardId);
        }
      },
      onError: (error) {
        _log('Error in card activation: ${error.message}', level: 1);
        if (onError != null) {
          onError(error);
        }
      },
    );
  }
  
  /// Enable debug logging for NFC operations
  static void enableDebugLogging(bool enable, {int logLevel = 3}) {
    _debugLogging = enable;
    _logLevel = logLevel.clamp(0, 4);
    
    // Also set debug mode in writer and reader
    _writer.setDebugMode(enable);
    
    _log('Debug logging ${enable ? 'enabled' : 'disabled'} with level: $_logLevel', level: 1);
  }
  
  /// Dumps the read tag data to console for debugging
  static Future<String> dumpTagRawData() async {
    _log('Dumping raw tag data', level: 3);
    try {
      final platformNFC = await _reader.dumpRawTagData();
      _log('Raw tag data: $platformNFC', level: 4);
      return platformNFC.toString();
    } catch (e) {
      _log('Error dumping tag data: $e', level: 1);
      return 'Error: ${e.toString()}';
    }
  }

  /// Internal logging helper
  static void _log(String message, {required int level}) {
    if (_debugLogging && level <= _logLevel) {
      final String prefix;
      switch (level) {
        case 1:
          prefix = '❌ ERROR';
          break;
        case 2:
          prefix = '⚠️ WARNING';
          break;
        case 3:
          prefix = 'ℹ️ INFO';
          break;
        case 4:
          prefix = '🔍 DEBUG';
          break;
        default:
          prefix = 'LOG';
      }
      developer.log('$prefix | $message', name: 'SwahiliNFC');
    }
  }
}
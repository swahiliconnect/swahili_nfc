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
// Removed unused import: dart:typed_data

import 'src/core/reader.dart';
import 'src/core/writer.dart';
import 'src/core/session_manager.dart';
import 'src/models/business_card.dart';
// Removed unused import: src/models/device_info.dart
import 'src/models/scan_record.dart';
import 'src/security/encryption.dart';
import 'src/security/authentication.dart';
// Removed unused import: src/security/tamper_detection.dart
// Removed unused import: src/utils/ndef_helper.dart
import 'src/utils/error_handler.dart';
import 'src/utils/analytics.dart';

/// The main class for SwahiliNFC operations.
class SwahiliNFC {
  static final _reader = NFCReader();
  static final _writer = NFCWriter();
  static final _sessionManager = SessionManager();
  static final _encryption = Encryption(); // Now used in generateRandomKey method
  static final _authentication = Authentication();
  static final _analytics = Analytics();

  /// Checks if NFC is available on the device.
  static Future<bool> isAvailable() async {
    return await _sessionManager.isNFCAvailable();
  }

  /// Reads an NFC tag and returns the business card data.
  static Future<BusinessCardData> readTag() async {
    return await _reader.readTag();
  }

  /// Starts background scanning for NFC tags.
  static void startBackgroundScan({
    required Function(BusinessCardData) onTagDetected,
    Duration scanDuration = const Duration(minutes: 5),
  }) {
    _reader.startBackgroundScan(
      onTagDetected: onTagDetected,
      scanDuration: scanDuration,
    );
  }

  /// Writes business card data to an NFC tag.
  static Future<bool> writeTag({
    required BusinessCardData data,
    bool verifyAfterWrite = true,
  }) async {
    return await _writer.writeTag(
      data: data,
      verifyAfterWrite: verifyAfterWrite,
    );
  }

  /// Sets security level for a card.
  static Future<void> setCardSecurity({
    required SecurityLevel securityLevel,
    required SecurityCredentials credentials,
  }) async {
    await _authentication.setCardSecurity(
      securityLevel: securityLevel,
      credentials: credentials,
    );
  }

  /// Reads a protected NFC tag using provided credentials.
  static Future<BusinessCardData> readProtectedTag({
    required SecurityCredentials credentials,
    Function(String)? onAuthenticationError,
  }) async {
    return await _reader.readProtectedTag(
      credentials: credentials,
      onAuthenticationError: onAuthenticationError,
    );
  }

  /// Gets list of active cards.
  static Future<List<BusinessCardData>> getActiveCards() async {
    return await _sessionManager.getActiveCards();
  }

  /// Deactivates a specific card by ID.
  static Future<void> deactivateCard({
    required String cardId,
  }) async {
    await _sessionManager.deactivateCard(cardId: cardId);
  }

  /// Activates a new NFC card/device.
  static Future<String> activateNewCard({
    required NFCDeviceType deviceType,
    required String deviceName,
  }) async {
    return await _sessionManager.activateNewCard(
      deviceType: deviceType,
      deviceName: deviceName,
    );
  }

  /// Enables analytics collection.
  static void enableAnalytics({
    required AnalyticsConfig analyticsConfig,
  }) {
    _analytics.enableAnalytics(analyticsConfig: analyticsConfig);
  }

  /// Gets scan history for a specific card.
  static Future<List<ScanRecord>> getCardScanHistory({
    required String cardId,
  }) async {
    return await _analytics.getCardScanHistory(cardId: cardId);
  }

  /// Enables offline mode.
  static void enableOfflineMode({
    int cacheSize = 100,
    bool syncWhenOnline = true,
  }) {
    _sessionManager.enableOfflineMode(
      cacheSize: cacheSize,
      syncWhenOnline: syncWhenOnline,
    );
  }

  /// Forces sync of offline data.
  static Future<void> syncOfflineData() async {
    await _sessionManager.syncOfflineData();
  }

  /// Configures package for SwahiliCard integration.
  static void configureForSwahiliCard({
    required String baseUrl,
    String? apiKey,
  }) {
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
    return _sessionManager.generateCardUrl(
      userId: userId,
      cardId: cardId,
      isSecure: isSecure,
    );
  }

  /// Generates a random encryption key.
  static String generateRandomKey() {
    return _encryption.generateRandomKey();
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
    _writer.startCardActivation(
      cardData: cardData,
      security: security,
      deviceType: deviceType,
      onActivationStarted: onActivationStarted,
      onProgress: onProgress,
      onActivationComplete: onActivationComplete,
      onError: onError,
    );
  }
}
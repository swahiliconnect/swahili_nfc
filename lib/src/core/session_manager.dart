import 'dart:async';

import '../models/business_card.dart';
import '../models/device_info.dart';
import '../platform/platform_nfc.dart';
import '../utils/error_handler.dart';

/// Manages NFC sessions and card-related operations
class SessionManager {
  final PlatformNFC _platformNFC = PlatformNFC.getInstance();
  
  // Storage for offline data
  final Map<String, BusinessCardData> _offlineCardCache = {};
  
  // Configuration
  bool _offlineModeEnabled = false;
  int _maxCacheSize = 100;
  bool _syncWhenOnline = true;
  
  // SwahiliCard specific configuration
  String? _baseUrl;
  String? _apiKey;
  
  /// Checks if NFC is available on the device
  Future<bool> isNFCAvailable() async {
    return await _platformNFC.isAvailable();
  }
  
  /// Gets a list of active cards
  Future<List<BusinessCardData>> getActiveCards() async {
    try {
      // Load from local storage first
      final localCards = await _loadCards();
      
      // If in offline mode, return local cards
      if (_offlineModeEnabled) {
        return localCards;
      }
      
      // Otherwise, try to sync with server
      try {
        // Implementation for server sync would go here
        // For now, just return local cards
        return localCards;
      } catch (e) {
        // If server sync fails, fallback to local cards
        return localCards;
      }
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.storageError,
        message: 'Failed to retrieve active cards: ${e.toString()}',
      );
    }
  }
  
  /// Deactivates a card by ID
  Future<void> deactivateCard({required String cardId}) async {
    try {
      // Load current cards
      final cards = await _loadCards();
      
      // Filter out the card to deactivate
      final updatedCards = cards.where((card) => card.cardId != cardId).toList();
      
      // Save updated list
      await _saveCards(updatedCards);
      
      // If not in offline mode, sync with server
      if (!_offlineModeEnabled && _syncWhenOnline) {
        // Server sync implementation would go here
      }
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.storageError,
        message: 'Failed to deactivate card: ${e.toString()}',
      );
    }
  }
  
  /// Activates a new NFC card/device
  Future<String> activateNewCard({
    required NFCDeviceType deviceType,
    required String deviceName,
  }) async {
    try {
      // Create device info
      final deviceInfo = NFCDeviceInfo(
        deviceId: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceType: deviceType,
        name: deviceName,
        activatedAt: DateTime.now(),
      );
      
      // Store device info locally
      await _saveDeviceInfo(deviceInfo);
      
      // If not in offline mode, sync with server
      if (!_offlineModeEnabled && _syncWhenOnline) {
        // Server sync implementation would go here
      }
      
      return deviceInfo.deviceId;
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.activationError,
        message: 'Failed to activate new card: ${e.toString()}',
      );
    }
  }
  
  /// Enables offline mode
  void enableOfflineMode({
    int cacheSize = 100,
    bool syncWhenOnline = true,
  }) {
    _offlineModeEnabled = true;
    _maxCacheSize = cacheSize;
    _syncWhenOnline = syncWhenOnline;
    
    // Limit cache size if needed
    if (_offlineCardCache.length > _maxCacheSize) {
      // Remove oldest entries to meet cache size limit
      final sortedKeys = _offlineCardCache.keys.toList()
        ..sort((a, b) => _offlineCardCache[a]!.createdAt.compareTo(_offlineCardCache[b]!.createdAt));
      
      while (_offlineCardCache.length > _maxCacheSize) {
        _offlineCardCache.remove(sortedKeys.first);
        sortedKeys.removeAt(0);
      }
    }
  }
  
  /// Forces sync of offline data
  Future<void> syncOfflineData() async {
    if (_offlineCardCache.isEmpty) {
      return;
    }
    
    try {
      // Implementation for server sync would go here
      // For now, just clear the cache
      _offlineCardCache.clear();
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.syncError,
        message: 'Failed to sync offline data: ${e.toString()}',
      );
    }
  }
  
  /// Configures SwahiliCard integration
  void configureForSwahiliCard({
    required String baseUrl,
    String? apiKey,
  }) {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
  }
  
  /// Generates a SwahiliCard compatible URL
  String generateCardUrl({
    required String userId,
    required String cardId,
    bool isSecure = true,
  }) {
    if (_baseUrl == null) {
      throw NFCError(
        code: NFCErrorCode.configError,
        message: 'SwahiliCard not configured. Call configureForSwahiliCard first.',
      );
    }
    
    final protocol = isSecure ? 'https://' : 'http://';
    final url = '$protocol${_baseUrl!.replaceAll(RegExp(r'^https?://'), '')}';
    
    // Removed unnecessary braces in string interpolation
    final apiKeyParam = _apiKey != null ? '?key=$_apiKey' : '';
    
    return '$url/$userId/$cardId$apiKeyParam';
  }
  
  // Private helper methods
  
  /// Loads cards from local storage
  Future<List<BusinessCardData>> _loadCards() async {
    try {
      // In a real implementation, this would read from secure storage
      // For now, just return an empty list
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Saves cards to local storage
  Future<void> _saveCards(List<BusinessCardData> cards) async {
    try {
      // In a real implementation, this would write to secure storage
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.storageError,
        message: 'Failed to save cards: ${e.toString()}',
      );
    }
  }
  
  /// Saves device info to local storage
  Future<void> _saveDeviceInfo(NFCDeviceInfo deviceInfo) async {
    try {
      // In a real implementation, this would write to secure storage
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.storageError,
        message: 'Failed to save device info: ${e.toString()}',
      );
    }
  }
}
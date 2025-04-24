import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/business_card.dart';
import '../models/scan_record.dart';
import '../utils/error_handler.dart';

/// Handles analytics collection for card scans
class Analytics {
  // Analytics configuration
  AnalyticsConfig? _config;

  // Local storage for scan records
  final List<ScanRecord> _scanRecords = [];

  /// Enables analytics collection
  void enableAnalytics({
    required AnalyticsConfig analyticsConfig,
  }) {
    _config = analyticsConfig;
  }

  /// Records a card scan
  Future<void> recordScan({
    required String cardId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_config == null) {
      return; // Analytics not enabled
    }

    try {
      // Create scan record
      final scanRecord = ScanRecord(
        cardId: cardId,
        timestamp: DateTime.now(),
        deviceModel:
            _config!.collectDeviceInfo ? await _getDeviceModel() : null,
        deviceOs: _config!.collectDeviceInfo ? await _getDeviceOs() : null,
        location: _config!.collectLocationData ? await _getLocation() : null,
        metadata: metadata,
      );

      // Store locally
      _scanRecords.add(scanRecord);

      // Store in persistent storage
      await _saveScanRecord(scanRecord);

      // Send to server (if implemented)
      _sendScanToServer(scanRecord);
    } catch (e) {
      // Silent failure for analytics
      if (kDebugMode) {
        print('Failed to record scan: ${e.toString()}');
      }
    }
  }

  /// Gets scan history for a specific card
  Future<List<ScanRecord>> getCardScanHistory({
    required String cardId,
  }) async {
    try {
      // Load from persistent storage
      final allRecords = await _loadScanRecords();

      // Filter by card ID
      return allRecords.where((record) => record.cardId == cardId).toList();
    } catch (e) {
      throw NFCError(
        code: NFCErrorCode.storageError,
        message: 'Failed to retrieve scan history: ${e.toString()}',
      );
    }
  }

  /// Gets device model (if allowed)
  Future<String?> _getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        // For Android, we could use device_info package
        return 'Android Device';
      } else if (Platform.isIOS) {
        // For iOS, we could use device_info package
        return 'iOS Device';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets device OS (if allowed)
  Future<String?> _getDeviceOs() async {
    try {
      if (Platform.isAndroid) {
        return 'Android ${Platform.operatingSystemVersion}';
      } else if (Platform.isIOS) {
        return 'iOS ${Platform.operatingSystemVersion}';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets location (if allowed)
  Future<String?> _getLocation() async {
    // In a real implementation, this would use the location package
    // For this example, we'll return null
    return null;
  }

  /// Saves scan record to persistent storage
  Future<void> _saveScanRecord(ScanRecord record) async {
    try {
      // In a real implementation, this would save to secure storage
      // For this example, we'll just keep it in memory
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save scan record: ${e.toString()}');
      }
    }
  }

  /// Loads scan records from persistent storage
  Future<List<ScanRecord>> _loadScanRecords() async {
    try {
      // In a real implementation, this would load from secure storage
      // For this example, we'll just return the in-memory records
      return _scanRecords;
    } catch (e) {
      return [];
    }
  }

  /// Sends scan record to server
  void _sendScanToServer(ScanRecord record) {
    try {
      // In a real implementation, this would send data to a server
      // For this example, we'll just print to console in debug mode
      if (kDebugMode) {
        print(
            'Would send scan record to server: ${json.encode(record.toJson())}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to send scan to server: ${e.toString()}');
      }
    }
  }
}

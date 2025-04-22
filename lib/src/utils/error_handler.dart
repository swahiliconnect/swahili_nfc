/// Enum for NFC error codes
enum NFCErrorCode {
  // General errors
  unknown,
  platformNotSupported,
  
  // Session errors
  sessionError,
  
  // Read/write errors
  readError,
  writeError,
  verificationError,
  
  // Security errors
  securityError,
  authenticationError,
  encryptionError,
  tamperError,
  
  // Storage errors
  storageError,
  
  // Sync errors
  syncError,
  
  // Configuration errors
  configError,
  
  // Activation errors
  activationError,
}

/// Class representing an NFC error
class NFCError implements Exception {
  /// Error code
  final NFCErrorCode code;
  
  /// Error message
  final String message;
  
  /// Error details (optional)
  final dynamic details;
  
  /// Creates a new NFC error
  NFCError({
    required this.code,
    required this.message,
    this.details,
  });
  
  @override
  String toString() {
    if (details != null) {
      return 'NFCError [${code.toString().split('.').last}]: $message\nDetails: $details';
    }
    return 'NFCError [${code.toString().split('.').last}]: $message';
  }
  
  /// Maps error code to user-friendly message
  String get userMessage {
    switch (code) {
      case NFCErrorCode.platformNotSupported:
        return 'NFC is not supported on this device';
        
      case NFCErrorCode.sessionError:
        return 'There was a problem with the NFC session';
        
      case NFCErrorCode.readError:
        return 'Could not read the NFC tag';
        
      case NFCErrorCode.writeError:
        return 'Could not write to the NFC tag';
        
      case NFCErrorCode.verificationError:
        return 'Tag data verification failed';
        
      case NFCErrorCode.securityError:
      case NFCErrorCode.authenticationError:
      case NFCErrorCode.encryptionError:
      case NFCErrorCode.tamperError:
        return 'Security verification failed';
        
      case NFCErrorCode.storageError:
        return 'Could not access stored data';
        
      case NFCErrorCode.syncError:
        return 'Could not sync data with server';
        
      case NFCErrorCode.configError:
        return 'Invalid configuration';
        
      case NFCErrorCode.activationError:
        return 'Card activation failed';
        
      case NFCErrorCode.unknown:
      default:
        return 'An unknown error occurred';
    }
  }
  
  /// Gets troubleshooting tips based on error code
  List<String> get troubleshootingTips {
    switch (code) {
      case NFCErrorCode.platformNotSupported:
        return [
          'Ensure your device has NFC hardware',
          'Check if NFC is enabled in your device settings',
        ];
        
      case NFCErrorCode.sessionError:
        return [
          'Restart the app and try again',
          'Ensure NFC is enabled in your device settings',
        ];
        
      case NFCErrorCode.readError:
        return [
          'Hold the card closer to your device',
          'Hold the card steady for a few seconds',
          'Try a different position on your device',
          'Ensure there are no other NFC cards nearby',
        ];
        
      case NFCErrorCode.writeError:
        return [
          'Hold the card closer to your device',
          'Hold the card steady for a few seconds',
          'Check if the card is write-protected',
          'Ensure there are no other NFC cards nearby',
        ];
        
      case NFCErrorCode.verificationError:
        return [
          'Try writing the data again',
          'Check if the card has sufficient storage',
          'Ensure the card is not damaged',
        ];
        
      case NFCErrorCode.securityError:
      case NFCErrorCode.authenticationError:
      case NFCErrorCode.encryptionError:
      case NFCErrorCode.tamperError:
        return [
          'Check if you are using the correct password or key',
          'The card might be protected with a different security level',
          'The card might have been tampered with',
        ];
        
      case NFCErrorCode.storageError:
        return [
          'Restart the app and try again',
          'Check your device storage permissions',
        ];
        
      case NFCErrorCode.syncError:
        return [
          'Check your internet connection',
          'Try again later',
        ];
        
      case NFCErrorCode.configError:
        return [
          'Check your configuration settings',
          'Ensure you have called the setup methods correctly',
        ];
        
      case NFCErrorCode.activationError:
        return [
          'Try the activation process again',
          'Ensure the card is compatible',
          'Hold the card steady during the entire process',
        ];
        
      case NFCErrorCode.unknown:
      default:
        return [
          'Restart the app and try again',
          "Check if your device's NFC is functioning properly",
          'Ensure you are using a compatible NFC card',
        ];
    }
  }
}
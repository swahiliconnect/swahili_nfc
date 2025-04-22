# SwahiliNFC

A comprehensive Flutter package for NFC business card applications with a focus on secure contact exchange.

## Overview

SwahiliNFC simplifies NFC operations for business card applications, abstracting the complexities of NFC communication while providing robust security features and an intuitive API.

Originally developed for SwahiliCard, this package helps developers quickly implement NFC functionality without the need to understand the underlying NFC protocols and security implementations.

## Key Features

- **Simplified Tag Operations**: One-line tag reading with automatic format detection
- **Advanced Security Model**: Multiple protection levels from open access to encrypted data with digital signatures
- **Business Card Data Format**: Standardized format specifically for contact exchange
- **Multi-Device Management**: Support for different NFC form factors (cards, tags, wristbands)
- **Analytics & Insights**: Built-in support for scan analytics
- **Offline Capabilities**: Cache contacts for offline exchange

## Installation

Add SwahiliNFC to your `pubspec.yaml`:

```yaml
dependencies:
  swahili_nfc: ^0.1.0
```

## Platform Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />
```

### iOS

Add the following to your `Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to read and write business cards</string>
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
    <string>TAG</string>
</array>
```

You'll also need to enable the NFC capabilities in your app's entitlements.

## Usage

### Basic Reading

```dart
// Simple read operation
final cardData = await SwahiliNFC.readTag();

// Continuous background reading
SwahiliNFC.startBackgroundScan(
  onTagDetected: (CardData data) {
    // Process the data
  },
  scanDuration: Duration(minutes: 5),
);
```

### Basic Writing

```dart
// Write operation with verification
final success = await SwahiliNFC.writeTag(
  data: BusinessCardData(
    name: "John Doe",
    company: "SwahiliTech",
    phone: "+25571234567",
    email: "john@example.com",
    social: {
      "linkedin": "johndoe",
      "twitter": "@johndoe",
    },
    custom: {
      "position": "Software Engineer",
      "website": "example.com",
    },
  ),
  verifyAfterWrite: true,
);
```

### Security

```dart
// Applying security to a card
await SwahiliNFC.setCardSecurity(
  securityLevel: SecurityLevel.enhanced,
  credentials: SecurityCredentials(
    password: "1234",
    encryptionKey: generateRandomKey(),
    expiration: DateTime.now().add(Duration(days: 365)),
  ),
);

// Reading a protected card
final cardData = await SwahiliNFC.readProtectedTag(
  credentials: SecurityCredentials(
    password: "1234",
  ),
  onAuthenticationError: (error) {
    // Handle authentication failure
  },
);
```

### Card Management

```dart
// List all active cards
final activeCards = await SwahiliNFC.getActiveCards();

// Deactivate a specific card
await SwahiliNFC.deactivateCard(cardId: "abc123");

// Activate a new card
final newCardId = await SwahiliNFC.activateNewCard(
  deviceType: NFCDeviceType.card,
  deviceName: "Metal Business Card",
);
```

### Analytics

```dart
// Enable scan analytics
SwahiliNFC.enableAnalytics(
  analyticsConfig: AnalyticsConfig(
    collectLocationData: false,
    collectDeviceInfo: true,
    collectTimestamps: true,
  ),
);

// Get scan history for a card
final scanHistory = await SwahiliNFC.getCardScanHistory(
  cardId: "abc123",
);
```

### Offline Mode

```dart
// Enable offline mode
SwahiliNFC.enableOfflineMode(
  cacheSize: 100, // Maximum number of contacts to store offline
  syncWhenOnline: true,
);

// Force sync when back online
await SwahiliNFC.syncOfflineData();
```

### SwahiliCard Integration

```dart
// SwahiliCard specific configuration
SwahiliNFC.configureForSwahiliCard(
  baseUrl: "https://me.swahilicard.com/",
  apiKey: "your_api_key", // Optional
);

// Generate SwahiliCard compatible URL
final cardUrl = SwahiliNFC.generateCardUrl(
  userId: "user123",
  cardId: "card456",
  isSecure: true,
);
```

## Complete Example: Card Activation Flow

```dart
Future<void> activateNewCard() async {
  // 1. Check NFC availability
  final isAvailable = await SwahiliNFC.isAvailable();
  if (!isAvailable) {
    showError('NFC not available on this device');
    return;
  }
  
  // 2. Get user profile
  final userProfile = await getUserProfile();
  
  // 3. Prepare business card data
  final cardData = BusinessCardData(
    name: userProfile.name,
    company: userProfile.company,
    position: userProfile.position,
    email: userProfile.email,
    phone: userProfile.phone,
    social: userProfile.socialLinks,
    profileImage: userProfile.profileImageBytes,
  );
  
  // 4. Configure security
  final securityOptions = SecurityOptions(
    level: SecurityLevel.enhanced,
    password: generatePassword(),
    expiry: DateTime.now().add(Duration(days: 365)),
  );
  
  // 5. Start the writing process
  SwahiliNFC.startCardActivation(
    cardData: cardData,
    security: securityOptions,
    deviceType: NFCDeviceType.card,
    
    // 6. Event callbacks
    onActivationStarted: () {
      showProgress('Please hold your card near the device');
    },
    onProgress: (progress) {
      updateProgressBar(progress);
    },
    onActivationComplete: (cardId) {
      showSuccess('Card activated successfully');
      
      // 7. Register card with backend
      registerCardWithBackend(cardId);
    },
    onError: (error) {
      showError('Activation failed: ${error.message}');
    },
  );
}
```

## Security Implementation Details

### Data Protection

- AES-256 encryption for sensitive data
- Secure storage of encryption keys
- Key rotation policies
- Tamper detection mechanisms

### Authentication Methods

- PIN/Password authentication
- App-based authentication
- Biometric authentication (where available)
- Time-based one-time passwords (TOTP)

### Anti-Cloning Features

- Unique device signatures
- Rate limiting on authentications
- Anomaly detection for suspicious scan patterns

## Cross-Platform Considerations

### Android

- Handles different NFC formats (NDEF, ISO-DEP, NfcA, etc.)
- Manages Android's Foreground Dispatch system
- Supports Android Beam for older devices

### iOS

- Works with CoreNFC
- Handles limited iOS NFC capabilities
- Manages iOS-specific permission prompts
- Provides alternative solutions for older iOS devices

## Commercial Applications

Beyond the open-source core, SwahiliNFC supports commercial applications:

- Enterprise security features
- White-labeling capabilities
- Analytics dashboard integration
- High-volume card provisioning
- Custom hardware integrations

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
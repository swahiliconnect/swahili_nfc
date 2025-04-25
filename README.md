# SwahiliNFC

A comprehensive Flutter package for NFC business card applications with a focus on secure contact exchange.

[![pub package](https://img.shields.io/pub/v/swahili_nfc.svg)](https://pub.dev/packages/swahili_nfc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

SwahiliNFC simplifies NFC operations for business card applications, abstracting the complexities of NFC communication while providing robust security features and an intuitive API.

Originally developed for SwahiliCard, this package helps developers quickly implement NFC functionality without the need to understand the underlying NFC protocols and security implementations.

<img src="https://raw.githubusercontent.com/swahiliconnect/swahili_nfc/main/doc/images/swahilinfc_demo.gif" alt="SwahiliNFC Demo" width="300"/>

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
  swahili_nfc: ^0.1.11
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

## Basic Usage

### Reading an NFC Card

```dart
// Check if NFC is available
final isAvailable = await SwahiliNFC.isAvailable();
if (!isAvailable) {
  print('NFC is not available on this device');
  return;
}

// Read a card
try {
  final cardData = await SwahiliNFC.readTag();
  print('Card read successfully: ${cardData.name}');
} catch (e) {
  print('Error reading card: $e');
}
```

### Writing an NFC Card

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

### Background Scanning

```dart
// Continuous background reading
SwahiliNFC.startBackgroundScan(
  onTagDetected: (CardData data) {
    // Process the data
    print('Card detected: ${data.name}');
  },
  scanDuration: Duration(minutes: 5),
);
```

## Advanced Features

### Security Levels

SwahiliNFC offers four security levels for your NFC cards:

1. **Open** (`SecurityLevel.open`):
   - Standard NDEF records, readable by any NFC reader
   - No authentication required
   - Great for public information sharing

2. **Basic** (`SecurityLevel.basic`):
   - Password-protected with simple PIN/password
   - Lightweight security for semi-private information

3. **Enhanced** (`SecurityLevel.enhanced`):
   - Encrypted data with app-specific decryption
   - Strong protection for sensitive information

4. **Premium** (`SecurityLevel.premium`):
   - Digital signatures and authentication tokens
   - Tamper detection to prevent modification
   - Highest level of security for critical data

### Applying Security

```dart
// Applying security to a card
await SwahiliNFC.setCardSecurity(
  securityLevel: SecurityLevel.enhanced,
  credentials: SecurityCredentials(
    password: "1234",
    encryptionKey: SwahiliNFC.generateRandomKey(),
    expiration: DateTime.now().add(Duration(days: 365)),
  ),
);
```

### Reading Protected Cards

```dart
// Reading a protected card
final cardData = await SwahiliNFC.readProtectedTag(
  credentials: SecurityCredentials(
    password: "1234",
  ),
  onAuthenticationError: (error) {
    // Handle authentication failure
    print('Authentication error: $error');
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

## Advanced Use Cases

### Working with Multiple Security Levels

If your application needs to support different security levels based on user needs:

```dart
enum CardUserType { public, staff, admin }

SecurityLevel getSecurityLevelForUser(CardUserType userType) {
  switch (userType) {
    case CardUserType.public:
      return SecurityLevel.open;
    case CardUserType.staff:
      return SecurityLevel.basic;
    case CardUserType.admin:
      return SecurityLevel.premium;
    default:
      return SecurityLevel.open;
  }
}

void createCardForUser(String name, CardUserType userType) async {
  // Create card data
  final cardData = BusinessCardData(
    name: name,
    // Other fields...
  );
  
  // Get appropriate security level
  final securityLevel = getSecurityLevelForUser(userType);
  
  // Configure security based on level
  SecurityCredentials credentials;
  switch (securityLevel) {
    case SecurityLevel.open:
      credentials = SecurityCredentials();
      break;
    case SecurityLevel.basic:
      credentials = SecurityCredentials(
        password: generateSimplePassword(),
      );
      break;
    case SecurityLevel.enhanced:
    case SecurityLevel.premium:
      final encryptionKey = SwahiliNFC.generateRandomKey();
      credentials = SecurityCredentials(
        password: generateSimplePassword(),
        encryptionKey: encryptionKey,
        expiration: DateTime.now().add(Duration(days: 365)),
      );
      // Store encryption key securely for later use
      await storeEncryptionKey(encryptionKey);
      break;
  }
  
  // Set security
  await SwahiliNFC.setCardSecurity(
    securityLevel: securityLevel,
    credentials: credentials,
  );
  
  // Write card
  await SwahiliNFC.writeTag(data: cardData);
}
```

### Event Registration System

For creating an NFC-based event registration system:

```dart
class EventAttendee {
  final String name;
  final String email;
  final String ticketId;
  final bool isVIP;
  
  EventAttendee({
    required this.name,
    required this.email,
    required this.ticketId,
    this.isVIP = false,
  });
  
  // Convert to BusinessCardData for NFC writing
  BusinessCardData toBusinessCardData() {
    return BusinessCardData(
      name: name,
      email: email,
      custom: {
        'ticketId': ticketId,
        'isVIP': isVIP.toString(),
        'eventName': 'Tech Conference 2024',
      },
      cardType: CardType.event,
      isTemporary: true,
    );
  }
  
  // Create from BusinessCardData when reading NFC
  static EventAttendee fromBusinessCardData(BusinessCardData data) {
    return EventAttendee(
      name: data.name,
      email: data.email ?? '',
      ticketId: data.custom['ticketId'] ?? '',
      isVIP: data.custom['isVIP'] == 'true',
    );
  }
}

// Register attendee and write to their NFC badge
Future<void> registerAttendee(EventAttendee attendee) async {
  // Convert to business card format
  final cardData = attendee.toBusinessCardData();
  
  // Write to NFC badge
  await SwahiliNFC.writeTag(
    data: cardData,
    verifyAfterWrite: true,
  );
  
  // Track attendance with analytics
  SwahiliNFC.enableAnalytics(
    analyticsConfig: AnalyticsConfig(
      collectTimestamps: true,
      collectDeviceInfo: false,
    ),
  );
}

// Check in attendee by scanning their badge
Future<void> checkInAttendee() async {
  try {
    // Read NFC badge
    final cardData = await SwahiliNFC.readTag();
    
    // Convert to attendee
    final attendee = EventAttendee.fromBusinessCardData(cardData);
    
    // Register check-in
    await recordAttendeeCheckIn(attendee);
    
    // Show confirmation
    showMessage('Welcome, ${attendee.name}!');
    if (attendee.isVIP) {
      showMessage('VIP access granted!');
    }
  } catch (e) {
    showError('Failed to check in: $e');
  }
}
```

## Error Handling

SwahiliNFC provides detailed error codes and messages to help you troubleshoot issues:

```dart
try {
  await SwahiliNFC.readTag();
} catch (e) {
  if (e is NFCError) {
    // Access error details
    print('Error code: ${e.code}');
    print('Error message: ${e.message}');
    print('User-friendly message: ${e.userMessage}');
    
    // Get troubleshooting tips
    for (final tip in e.troubleshootingTips) {
      print('Tip: $tip');
    }
  }
}
```

## Documentation

For full documentation, please see:
- [API Reference](https://pub.dev/documentation/swahili_nfc/latest/)
- [Example App](https://github.com/swahiliconnect/swahili_nfc/tree/main/example)

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
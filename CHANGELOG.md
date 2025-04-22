# Changelog

## 0.1.0 - Initial Release (2024-04-22)

### Added

- Core NFC functionality:
  - Reading NFC tags (one-time and background scanning)
  - Writing to NFC tags with verification
  - Card activation workflow

- Security features:
  - Four security levels (Open, Basic, Enhanced, Premium)
  - AES-256 encryption for sensitive data
  - Digital signatures for tamper detection
  - Authentication mechanisms

- Business card data model:
  - Standardized format for contact exchange
  - Support for social media links and custom fields
  - Profile image storage

- Multi-device management:
  - Support for different NFC form factors
  - Device activation and deactivation
  - Device information tracking

- Analytics capabilities:
  - Scan history recording
  - Device and timestamp tracking (optional)
  - Configurable privacy settings

- Offline support:
  - Caching for offline operation
  - Sync when online capability

- SwahiliCard integration:
  - Compatible with SwahiliCard ecosystem
  - URL generation for digital cards
  - API integration

- Platform-specific implementations:
  - Android implementation with Foreground Dispatch
  - iOS implementation with CoreNFC
  - Cross-platform API abstraction
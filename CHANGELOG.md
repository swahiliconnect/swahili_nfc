# Changelog

## 0.1.14 - bug fixes (2024-04-25)

### Fixed
- SwahiliNFC plugin registration bug fixes

## 0.1.13 - Fix SwahiliNFC plugin registration (2024-04-25)

### Fixed
- SwahiliNFC plugin registration and unresolved Registrar reference

## 0.1.12 - Fix SwahiliNFC plugin registration (2024-04-25)

### Fixed
- SwahiliNFC plugin registration and unresolved Registrar reference

## 0.1.11 - Android Namespace Fix (2024-04-25)

### Fixed
- Added namespace property to Android build.gradle
- Fixed compatibility with newer versions of Android Gradle Plugin

## 0.1.10 - Android Plugin Structure Fix (2024-04-25)

### Fixed
- Fixed Android plugin class naming and directory structure
- Added proper Java implementation in the correct location
- Added correctly named Kotlin implementation class

## 0.1.9 - Android Plugin Package Fix (2024-04-25)

### Fixed
- Fixed package name typo in Android implementation (swaahilicard → swahilicard)
- Moved Java implementation to correct directory structure
- Fixed Java and Kotlin plugin registration

## 0.1.8 - Android Plugin File Structure Fix (2024-04-29)

### Fixed
- Fixed incorrect file paths for Android plugin implementation
- Properly structured Java and Kotlin implementation files
- Resolved "cannot find symbol: class SwahiliNFCPlugin" error

## 0.1.7 - Android Plugin Registration Fix (2024-04-28)

### Fixed
- Added Java implementation of the plugin for direct Java compiler compatibility
- Renamed original Kotlin implementation to SwahiliNFCPluginKt
- Updated Gradle configuration to properly handle both Java and Kotlin sources

## 0.1.6 - Android Plugin Registration Fix (2024-04-28)

### Fixed
- Fixed Android plugin registration issue for compatibility with Flutter embedding v1
- Added proper static registration method for the Kotlin plugin class
- Improved nullability handling for Activity references
- Enhanced parcelable handling for Android 13+ (Tiramisu)
- Fixed potential memory leaks with activity references

### Improved
- Refactored channel setup code for better maintainability
- Added proper deprecation annotations and suppressions
- Better error handling during NFC operations


## 0.1.5 - Android Namespace Fix (2024-04-26)

### Fixed
- Added namespace property to Android build.gradle file
- Fixed compatibility with Android Gradle Plugin 8.0+
- Improved Android build configuration

## 0.1.4 - Android Gradle Fix (2024-04-26)

### Added
- Android Gradle configuration files
  - Added build.gradle for proper plugin configuration
  - Added settings.gradle to define project name
  - Added gradle.properties with Android X support

### Fixed
- Fixed "Could not get unknown property 'android'" error when integrating with apps
- Improved cross-platform compatibility
- Addressed formatting issues in Dart files

### Improved
- Added more comprehensive API documentation
- Updated example app with better error handling

## 0.1.3 - Example & Documentation Update (2024-04-25)

### Added
- Comprehensive example application demonstrating key features:
  - NFC card reading and writing
  - Card activation workflow
  - Security level implementation
  - UI for displaying scanned card details
- Enhanced documentation with more usage examples
- Better error handling in platform implementations

### Fixed
- Code formatting issues across multiple files
- Fixed pubspec.yaml to comply with pub.dev standards

## 0.1.2 - Bug Fixes (2024-04-24)

### Fixed
- Fixed Android NFC session handling
- Improved error messages for better troubleshooting
- Better handling of encrypted data

### Changed
- Optimized NDEF message handling for larger data payloads

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
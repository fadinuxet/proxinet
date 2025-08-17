# ProxiNet

**Privacy-first proximity networking platform**

ProxiNet is a Flutter-based application that enables secure, privacy-focused proximity networking using Bluetooth Low Energy (BLE) technology. The platform facilitates meaningful connections between nearby users while maintaining strict privacy controls and data security.

## Features

- 🔒 **Privacy-First Design** - End-to-end encryption and secure data handling
- 📍 **Proximity Detection** - BLE-based location awareness and user discovery
- 🔐 **Secure Authentication** - OAuth integration with Google and Apple Sign-In
- 💬 **Real-time Messaging** - Encrypted chat and communication system
- 📱 **Cross-Platform** - iOS, Android, Web, and macOS support
- 🌐 **Offline Capable** - Firebase offline persistence for reliable operation
- 🔔 **Push Notifications** - Real-time alerts and updates
- 🗺️ **Location Services** - Geolocation and mapping integration

## Architecture

Built with clean architecture principles:
- **Domain Layer** - Business logic and entities
- **Data Layer** - Repositories and data sources
- **Presentation Layer** - UI components and state management
- **Core Services** - Shared utilities and infrastructure

## Tech Stack

- **Frontend**: Flutter 3.3.0+
- **Backend**: Firebase (Auth, Firestore, Messaging, Storage)
- **State Management**: GetIt for dependency injection
- **Navigation**: GoRouter
- **Security**: Flutter Secure Storage + Crypto
- **BLE**: Flutter Blue Plus
- **Maps**: Flutter Map with OpenStreetMap

## Getting Started

### Prerequisites

- Flutter SDK 3.3.0 or higher
- Dart SDK 3.3.0 or higher
- Firebase project setup
- iOS/Android development environment

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/proxinet.git
cd proxinet
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Copy your `google-services.json` to `android/app/`
   - Copy your `GoogleService-Info.plist` to `ios/Runner/`
   - Update Firebase configuration in `lib/main.dart`

4. Run the app:
```bash
flutter run
```

## Development

### Project Structure

```
lib/
├── core/           # Core services and utilities
├── features/       # Feature-specific modules
├── proxinet/       # Main app configuration
└── main.dart       # App entry point
```

### Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions, please open an issue on GitHub or contact the development team.

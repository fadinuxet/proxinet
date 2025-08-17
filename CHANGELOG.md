# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Enhanced privacy controls
- Advanced proximity algorithms
- Social networking features
- Analytics and insights
- Third-party integrations

## [0.2.0] - 2024-12-19

### Added
- **Tabbed Map Interface** - Separated "Around Me" (BLE discovery) and "Available to Connect" (availability status) into distinct tabs
- **Enhanced Map Experience** - Three dedicated tabs: Around Me, Available, and Combined view
- **Improved User Experience** - Clear separation of proximity discovery and availability features
- **ProxinetPresenceSyncService** - New service for better presence management and synchronization
- **BLE Diagnostic Page** - New diagnostic interface for Bluetooth troubleshooting
- **Available People Page** - Dedicated page for viewing available users

### Changed
- **Map Page Restructure** - Completely redesigned map interface with tab-based navigation
- **Presence Management** - Enhanced presence synchronization using dedicated service
- **Navigation Flow** - Improved routing and page organization
- **Service Architecture** - Better separation of concerns with dedicated services

### Technical Improvements
- **Tab Controller Integration** - Proper lifecycle management for tab-based navigation
- **Service Integration** - Better integration with ProxinetPresenceSyncService
- **Code Organization** - Improved separation of map functionality into focused components
- **Performance Optimization** - Each tab loads only relevant data

## [0.1.0] - 2024-12-19

### Added
- Initial release
- Basic project structure and core services
- Firebase backend integration
- Authentication system
- Proximity networking foundation

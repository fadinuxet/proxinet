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

## [0.3.2] - 2024-12-19

### Fixed
- **Posts Visibility Issue**: Fixed critical bug where saved posts were not visible in "My Posts" section
- **Availability System Integration**: Resolved cross-device visibility issues with comprehensive debugging
- **User Interface Issues**: Fixed multiple UI/UX problems reported by users
- **Map Functionality**: Enhanced user interactions and prevented self-addition

### Changed
- **Posts Repository**: Fixed field ordering from `startAt` to `createdAt` for consistent post loading
- **User Dialogs**: Made all popups more compact to reduce screen space usage
- **Posts Page**: Added comprehensive debugging tools and toggle between user posts and all posts
- **Map Interactions**: Improved user marker interactions with smart button visibility

### Added
- **Debug Tools**: Added comprehensive debugging for availability and posts systems
- **Posts Toggle**: Users can now switch between "My Posts" and "All Posts" views
- **Enhanced Logging**: Better error tracking and debugging information throughout the app
- **Smart User Prevention**: Users can no longer add themselves to contacts
- **Compact UI**: Reduced popup sizes and improved space efficiency

### Technical Improvements
- **Better Error Handling**: Enhanced error handling with fallbacks and user feedback
- **Service Integration**: Improved integration between availability page and presence sync service
- **Data Consistency**: Fixed data field mismatches between post creation and retrieval
- **Performance**: Optimized post loading and availability updates

## [0.3.1] - 2024-12-19

### Fixed
- **Availability System Integration**: Fixed critical integration issue between availability page and presence sync service
- **Location Updates**: Availability now automatically updates user location in both Firestore collections
- **Map Discovery**: Users setting availability are now properly discoverable on the map
- **Service Integration**: Availability page now uses ProxinetPresenceSyncService instead of direct Firestore operations
- **User Experience**: Added location status indicators and manual refresh options

### Changed
- **Availability Page**: Enhanced with location services info and refresh location button
- **Data Flow**: Improved synchronization between availability and user profile collections
- **Error Handling**: Better error messages and fallbacks for location services

### Technical Improvements
- **Service Architecture**: Proper dependency injection and service integration
- **Location Management**: Automatic GPS location fetching and storage
- **Real-time Updates**: Map shows available users with current location data

## [0.3.0] - 2024-12-19

### Added
- **Serendipity Engine Foundation**: Interest-based matching and connection suggestions
- **Enhanced User Profiles**: Industry, skills, and networking goals fields
- **Smart Post Creation**: Intelligent tag suggestions based on user interests
- **Interest Matching System**: Algorithm to find users with similar interests in proximity
- **Event Overlap Detection**: Identify users attending events at the same time
- **Serendipity Suggestions**: Home page section showing potential connections
- **Auto-save Profile System**: Automatic saving of profile changes with visual feedback

### Changed
- **Profile Page**: Redesigned with new interest fields and better UX
- **Post Composer**: Enhanced with smart tag suggestions and better hints
- **Home Page**: Added serendipity suggestions section for better user engagement
- **User Experience**: Improved post-publish flow with success feedback and navigation

### Technical Improvements
- **New Data Models**: UserInterests class for structured interest data
- **Enhanced Services**: SerendipityService with matching algorithms
- **Better State Management**: Improved profile editing and auto-save functionality
- **Firestore Integration**: Enhanced data structure for interests and networking preferences

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

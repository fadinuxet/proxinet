# ProxiNet v0.2.0 Release Notes

**Release Date:** December 19, 2024  
**Version:** 0.2.0  
**Build Number:** 2

## 🎉 Major Update: Tabbed Map Interface

This release introduces a completely redesigned map experience with clear separation of proximity discovery and availability features, making it easier for users to focus on specific networking goals.

## ✨ What's New

### 🗺️ **Tabbed Map Interface**
- **Three Dedicated Tabs**:
  - **Around Me**: Focuses on BLE proximity discovery with radius controls
  - **Available**: Shows users who have set their availability to ON
  - **Combined**: Merges both views for comprehensive networking overview

### 🔍 **Enhanced User Experience**
- **Clear Feature Separation**: Users can now easily switch between different discovery modes
- **Focused Functionality**: Each tab shows only relevant information and controls
- **Improved Navigation**: Better organized interface with intuitive tab switching
- **Consistent Controls**: Radius controls and legends appear only when relevant

### 🏗️ **Technical Improvements**
- **ProxinetPresenceSyncService**: New dedicated service for better presence management
- **Tab Controller Integration**: Proper lifecycle management for tab-based navigation
- **Service Architecture**: Better separation of concerns with dedicated services
- **Performance Optimization**: Each tab loads only the data it needs

### 🆕 **New Features**
- **BLE Diagnostic Page**: Troubleshooting interface for Bluetooth connectivity issues
- **Available People Page**: Dedicated view for managing and viewing available users
- **Enhanced Presence Management**: Better synchronization and state management
- **Improved Map Legends**: Clear visual distinction between different user types

## 🔧 Technical Details

### Architecture Changes
- **Tab-Based Navigation**: Implemented using Flutter's TabController with proper lifecycle management
- **Service Integration**: Enhanced integration with ProxinetPresenceSyncService
- **Code Organization**: Improved separation of map functionality into focused components
- **State Management**: Better state handling for tab-specific data and controls

### Map Implementation
- **Separate Map Views**: Each tab has its own FlutterMap instance with appropriate markers
- **Dynamic Controls**: Radius controls and legends appear only when relevant
- **Marker Management**: Different marker types for nearby BLE users vs. available users
- **Performance**: Optimized loading and rendering for each tab

### Service Enhancements
- **Presence Synchronization**: Better real-time updates and state management
- **BLE Integration**: Improved proximity detection and user discovery
- **Data Loading**: Efficient loading of relevant data for each tab
- **Error Handling**: Enhanced error handling and user feedback

## 📱 User Interface Changes

### Map Tabs
1. **Around Me Tab**:
   - Shows only nearby BLE users
   - Includes radius controls and device legends
   - Focuses on proximity discovery functionality

2. **Available Tab**:
   - Shows only users who are available to connect
   - Clean interface without radius controls
   - Green markers for available users

3. **Combined Tab**:
   - Merges both nearby and available users
   - All controls and legends visible
   - Comprehensive networking overview

### Visual Improvements
- **Color-Coded Markers**: Different colors for different user types
- **Dynamic Legends**: Context-aware legend display
- **Responsive Controls**: Controls that adapt to the current tab
- **Better Information Architecture**: Clearer organization of features

## 🚀 Getting Started with New Features

### Using the Tabbed Interface
1. **Navigate to the Map Page** from the main ProxiNet interface
2. **Switch between tabs** using the tab bar at the top
3. **Around Me**: Enable nearby discovery and adjust radius
4. **Available**: View and connect with available users
5. **Combined**: Get a complete overview of networking opportunities

### New Pages
- **BLE Diagnostic**: Access via settings or troubleshooting menu
- **Available People**: Dedicated page for availability management
- **Enhanced Map**: Improved map experience with tabbed navigation

## 🔒 Privacy & Security

- **No Changes**: All existing privacy controls remain intact
- **Enhanced Security**: Better service isolation and error handling
- **User Control**: Users maintain full control over their visibility and connections

## 📋 Known Limitations

- BLE functionality still requires device permissions
- Some features may be platform-specific
- Offline mode has limited functionality
- Push notifications require internet connectivity

## 🐛 Bug Fixes

- **Map Interface**: Fixed mixed functionality issues by separating concerns
- **User Experience**: Improved clarity and focus in the map interface
- **Performance**: Better data loading and rendering for each tab
- **Navigation**: Cleaner tab switching and state management

## 🔮 Upcoming Features

Future releases will include:
- Enhanced privacy controls
- Advanced proximity algorithms
- Social networking features
- Analytics and insights
- Third-party integrations
- Additional map customization options

## 📞 Support

For technical support or feature requests:
- Create an issue on GitHub
- Check the updated documentation
- Contact the development team

## 📄 License

This release is licensed under the MIT License.

---

**ProxiNet Team**  
*Building the future of privacy-first networking*

---

## Migration Notes

### From v0.1.0 to v0.2.0
- **No Breaking Changes**: All existing functionality is preserved
- **Enhanced Interface**: Map page now uses tabs for better organization
- **Improved Services**: Better presence management and synchronization
- **New Pages**: Additional diagnostic and management interfaces

### User Experience Improvements
- **Clearer Navigation**: Tab-based interface makes features easier to find
- **Better Focus**: Users can concentrate on specific networking goals
- **Enhanced Controls**: Context-aware controls that adapt to user needs
- **Improved Performance**: Optimized loading and rendering for each view

# Putrace Release Notes v0.3.2

**Release Date:** December 19, 2024  
**Version:** 0.3.2+5  
**Build:** Release APK

## 🎯 What's New in This Release

### 🚀 **Major Fixes: Posts Visibility & Availability System**

This release addresses critical user-reported issues and significantly improves the overall app experience.

#### **What Was Fixed:**
- **Posts Visibility Issue**: Saved posts now properly appear in "My Posts" section
- **Availability System**: Cross-device visibility issues resolved with comprehensive debugging
- **User Interface**: Multiple UI/UX problems fixed for better user experience
- **Map Functionality**: Enhanced user interactions and prevented self-addition

## 🔧 Technical Improvements

### **Posts System Overhaul**
- **Fixed Repository Logic**: Changed post ordering from `startAt` to `createdAt` for consistency
- **Enhanced Debugging**: Added comprehensive debugging tools for troubleshooting
- **Dual View Mode**: Users can toggle between "My Posts" and "All Posts"
- **Better Error Handling**: Improved error messages and fallback mechanisms

### **Availability System Enhancement**
- **Service Integration**: Proper integration between availability page and presence sync service
- **Location Updates**: Automatic GPS location fetching and synchronization
- **Debug Tools**: Added status checking and manual location refresh options
- **Cross-Device Visibility**: Users now properly appear on other devices' maps

### **User Interface Improvements**
- **Compact Dialogs**: Reduced popup sizes to minimize screen space usage
- **Smart Interactions**: Users can no longer add themselves to contacts
- **Enhanced Navigation**: Improved chat and profile navigation
- **Better Feedback**: Clear success/error messages throughout the app

## 📱 New Features

### **Debug Tools**
- **Posts Debugging**: Toggle between user posts and all posts
- **Availability Debugging**: Status checking and location refresh
- **Enhanced Logging**: Better error tracking and debugging information
- **User ID Display**: Shows current user ID for troubleshooting

### **Posts Management**
- **Dual View Mode**: Switch between personal and all posts
- **Real-time Updates**: Posts appear immediately after creation
- **Better Organization**: Improved post display and management
- **Enhanced Actions**: Edit, archive, and delete functionality

### **Map Enhancements**
- **Smart User Prevention**: Can't interact with your own marker
- **Compact User Dialogs**: Smaller, more efficient popups
- **Enhanced Interactions**: Profile, chat, and contact features
- **Better Visual Feedback**: Clear indication of available actions

## 🐛 Bug Fixes

- **Fixed**: Posts not appearing in "My Posts" section
- **Fixed**: Availability system not working across devices
- **Fixed**: Users could add themselves to contacts
- **Fixed**: Popups taking too much screen space
- **Fixed**: Chat button not working properly
- **Fixed**: Add button not functioning correctly
- **Fixed**: Map visibility issues for available users

## 📋 Known Limitations

- Chat system needs full implementation for real-time messaging
- Some advanced features require additional development
- Performance optimizations are ongoing

## 🚀 Performance Notes

- Faster post loading with optimized queries
- Better error handling reduces crashes
- Improved availability system responsiveness
- Enhanced map performance with better data handling

## 📥 Installation

1. **Download** the APK file
2. **Enable** "Install from Unknown Sources" in Android settings
3. **Install** the APK
4. **Grant** location permissions when prompted
5. **Test** the fixed features

## 🧪 Testing the Fixes

### **Posts System:**
1. Go to Posts page (`/putrace/serendipity`)
2. Check debug section shows your user ID
3. Toggle between "My Posts" and "All Posts"
4. Create a test post and verify it appears

### **Availability System:**
1. Go to Availability page (`/putrace/availability`)
2. Set yourself as available
3. Use debug buttons to check status
4. Verify you appear on other devices' maps

### **Map Functionality:**
1. Go to Map page (`/putrace/map`)
2. Test all three tabs (Around Me, Available, Combined)
3. Click on user markers to test interactions
4. Verify compact dialogs and smart button visibility

## 🆘 Support

If you encounter any issues:
1. Check the debug information displayed in the app
2. Use the debug tools to troubleshoot
3. Check console logs for detailed error information
4. Contact support with specific error details

## 📈 What's Next

Future releases will include:
- **Complete Chat System**: Real-time messaging between users
- **Enhanced Contact Management**: Full contact request workflow
- **Serendipity Engine**: Interest-based matching and suggestions
- **Performance Optimizations**: Faster loading and better caching
- **Advanced Privacy Controls**: Granular visibility settings

---

**Putrace Team**  
*Building meaningful connections through proximity*

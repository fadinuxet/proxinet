Absolutely! Here's the updated `PROJECT_CONTEXT.md` file optimized for Cursor with all the comprehensive information we've discussed:

```markdown
# Putrace Project Context

## 🎯 Core Vision
Privacy-first professional networking platform with **three-mode availability system**: BLE Proximity, Location-Based, and Global Virtual. Solves the "I'm available to meet" problem that LinkedIn can't address properly.

## 🚀 Three Availability Modes

### 1. **BLE Proximity Mode** (✅ Implemented)
- "I'm physically here right now - discover me via Bluetooth"
- Real-time device-to-device discovery (~10-100m range)
- Perfect for conferences, events, immediate networking
- **Status**: ✅ Fully implemented

### 2. **Location-Based Mode** (✅ Implemented)  
- "I'll be at this location for a time window - find me via GPS"
- GPS + map-based discovery at specific venues
- Time-bounded availability (1-8 hours)
- **Status**: ✅ Fully implemented

### 3. **Global Virtual Mode** (🆕 HIGH PRIORITY)
- "I'm available online for virtual chats worldwide"
- Cloud-based, no location required
- Timezone-aware availability
- Virtual meeting types (video, audio, chat)
- **Status**: ❌ Not implemented - CURRENT FOCUS

## 📋 Current Status (35% Complete)

### ✅ **Solid Foundation (Fully Implemented)**
- **Architecture**: Flutter + Clean Architecture + GetIt DI
- **Authentication**: Firebase Auth with Google/Apple OAuth
- **BLE Proximity**: Complete BLE service with advertising/scanning
- **Location Services**: GPS, geocoding, map integration
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **UI Framework**: Material 3, responsive, cross-platform
- **Navigation**: GoRouter with 5 main sections

### ❌ **Missing Core Features (65% Remaining)**
- **Global Virtual Availability Mode** (CURRENT PRIORITY)
- Complete User Profile System
- Connection Management
- Real-time Messaging with WebSocket
- Content Engagement (likes, comments)
- AI Matching Algorithms
- Group Management
- Referral System
- Enterprise Features

## 🎯 **Immediate Priority: Global Virtual Mode**

### **Phase 1 Goal (Next 2-3 months)**
Implement complete Global Virtual Availability system:
- Virtual availability without location constraints
- Timezone-based scheduling
- Recurring availability patterns (e.g., weekly office hours)
- Virtual meeting types (video, audio, chat)
- Global discovery algorithms

### **Key User Stories to Implement**
- **US-117**: Virtual availability for online meetings
- **US-503**: Recruiter office hours for candidates  
- **US-504**: Remote worker virtual connectivity
- **US-305**: Virtual meeting coordination beyond basic chat

## 🔧 **Technical Stack**
- **Frontend**: Flutter 3.3.0+ with Dart
- **Backend**: Firebase (Auth, Firestore, Storage, Messaging)
- **Architecture**: Clean Architecture (Domain/Data/Presentation)
- **DI**: GetIt for service location
- **Navigation**: GoRouter
- **BLE**: flutter_blue_plus for proximity
- **Maps**: Google Maps for location-based
- **State**: Service-based with streams

## 🏗️ **Architecture Patterns**

### **Clean Architecture Structure**
```
lib/
├── domain/           # Business logic & entities
│   ├── entities/     # AvailabilitySession, User, etc.
│   ├── repositories/ # Abstract interfaces
│   └── use_cases/    # Business logic
├── data/             # Implementation details
│   ├── repositories/ # Firebase implementations
│   └── datasources/  # API, local storage
└── presentation/     # UI Layer
    ├── screens/      # Full pages
    ├── widgets/      # Reusable components
    └── state/        # UI state management
```

### **Current Services (✅ Implemented)**
- `PutraceBleService` - BLE proximity management
- `PutracePresenceService` - Location-based availability
- `ChatService` - Basic messaging structure
- `NotificationService` - Push notifications
- `FirebaseRepositories` - Data layer implementations

## ❗ **Important Constraints & Principles**

### **Privacy-First Design**
- Granular privacy controls for all three modes
- Data minimization - only collect necessary data
- Secure storage for sensitive information
- End-to-end encryption for messages (future)

### **Performance Requirements**
- Battery-efficient BLE usage (<5% per hour)
- <3s app launch time
- <1s navigation between screens
- Efficient Firestore queries with proper indexing

### **Cross-Platform Support**
- iOS, Android, Web, macOS compatibility
- Consistent UI/UX across all platforms
- Platform-specific optimizations where needed

## 🎯 **Success Metrics**
- **User Engagement**: 70%+ monthly retention
- **Performance**: <0.1% crash rate
- **Networking**: 30%+ connection-to-meeting conversion
- **Growth**: 50%+ month-over-month user growth

## 🔄 **Development Workflow**

### **When Starting New Features:**
1. Always begin with domain models (`lib/domain/entities/`)
2. Implement data layer (`lib/data/repositories/`)
3. Create domain use cases (`lib/domain/use_cases/`)
4. Build presentation layer (`lib/presentation/`)

### **Code Quality Standards:**
- No linter errors/warnings
- Comprehensive error handling
- Consistent naming conventions
- Good test coverage (target 80%+)
- Proper documentation for complex logic

## 🚀 **Quick Start for New Developers**

### **Key Files to Understand First:**
1. `lib/domain/entities/availability_session.dart` - Core availability model
2. `lib/domain/services/availability_service.dart` - Main coordination logic
3. `lib/data/repositories/availability_repository_impl.dart` - Data layer
4. `lib/presentation/screens/availability/` - UI components

### **Common Patterns:**
- Use `GetIt` for dependency injection: `getIt<AvailabilityService>()`
- Follow repository pattern for data access
- Use streams for real-time updates
- Implement proper error handling with custom exceptions

## 📞 **Contact & References**

### **Key Decision Log:**
- **Three-Mode Architecture**: Proximity, Location, Global Virtual
- **Privacy-First**: Granular controls for all features
- **Clean Architecture**: Strict separation of concerns
- **Firebase Backend**: Chosen for rapid development

### **Recent Important Decisions:**
- Global Virtual Mode prioritized for Phase 1
- Three-mode system covers 95% of user stories
- Virtual availability identified as key gap in current implementation

---

**Remember**: Always reference this context file when starting new work. The three-mode availability system is our core differentiator - keep it central to all feature development.
```

Note:
This updated context file now includes:

1. **Clear three-mode architecture** explanation
2. **Current implementation status** with what's done vs. missing
3. **Immediate priorities** (Global Virtual Mode as Phase 1)
4. **Technical architecture patterns** for consistency
5. **Development guidelines** for new team members
6. **Key constraints and principles** to maintain quality

To help maintain perfect context alignment across all development sessions!
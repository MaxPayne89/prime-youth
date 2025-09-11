# Prime Youth Mobile App

Kotlin Multiplatform Mobile (KMP) application for afterschool activities, camps, and class trips management.

## 🎨 Visual Design Reference

**👀 See the App in Action**: Check out the complete interactive mockup system in [`mockups/`](mockups/)

The mockup system shows:
- Complete user journeys (login to enrollment)
- All app screens with realistic data
- Interactive navigation and state changes
- Dark/light theme implementations
- Responsive design for different screen sizes

## 🏗️ Architecture Overview

**Status**: 🔄 Planning phase - KMP implementation upcoming

### Planned Architecture
```
mobile/
├── shared/                   # Shared business logic
│   ├── commonMain/          # Cross-platform code
│   ├── androidMain/         # Android-specific implementations
│   └── iosMain/            # iOS-specific implementations
├── androidApp/              # Android UI layer
├── iosApp/                  # iOS UI layer (SwiftUI)
└── mockups/                # 📱 Design reference (current)
```

### Technology Stack
- **KMP Framework**: Kotlin Multiplatform Mobile
- **Shared Logic**: Kotlin common code
- **Android UI**: Jetpack Compose  
- **iOS UI**: SwiftUI (planned)
- **Networking**: Ktor client
- **Data Storage**: SQLDelight
- **Dependency Injection**: Koin

## 🎯 Feature Scope

Based on the mockup system, the app will include:

### Core Features
- **User Authentication**: Login/signup with parental profiles
- **Dashboard**: Child management with progress tracking  
- **Program Discovery**: Browse and filter afterschool programs
- **Enrollment System**: Registration and payment processing
- **Schedule Management**: View upcoming activities and sessions
- **Social Features**: Community feed and instructor updates
- **Notifications**: Activity reminders and important updates

### User Personas
- **Parents**: Manage children's activities and schedules
- **Instructors**: Update programs and communicate with parents
- **Administrators**: Oversee programs and user management

## 🚀 Implementation Plan

### Phase 1: Foundation (Planned)
- [ ] KMP project setup with basic structure
- [ ] Shared data models and networking layer
- [ ] Authentication flow implementation
- [ ] Basic navigation structure

### Phase 2: Core Features (Planned)  
- [ ] Dashboard with child management
- [ ] Program browsing and filtering
- [ ] Enrollment flow and payment integration
- [ ] Push notification setup

### Phase 3: Enhanced Features (Future)
- [ ] Social feed implementation
- [ ] Advanced scheduling features
- [ ] Offline support and sync
- [ ] iOS app completion

## 📱 Development Setup

**Prerequisites** (when development begins):
- Android Studio
- Kotlin Multiplatform plugin
- iOS development environment (Xcode for iOS target)

**Current Status**: Setup instructions will be added when KMP development begins.

## 🔗 Related Resources

- **[Interactive Mockups](mockups/)** - Complete visual reference
- **[Design System](mockups/README.md)** - UI components and guidelines  
- **[Project Changelog](../CHANGELOG.md)** - Track development progress

---

**Note**: This directory currently focuses on design and mockup systems. KMP development will begin after design approval and backend API planning.
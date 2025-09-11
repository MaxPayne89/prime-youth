# Changelog

All notable changes to the Prime Youth project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2024-09-11

### Fixed
- **Mobile Mockups**: Resolved header icon visibility in iPhone 14 mockup frame
  - Removed problematic margin-right causing bell and gear icons to overflow
  - Added responsive sizing with clamp() for dynamic icon scaling (36-44px)
  - Implemented flex-shrink: 0 to prevent icon compression
  - Updated header padding system for consistent mobile spacing
  - Icons now remain fully visible across all phone frame sizes (300-375px)

### Added
- **Documentation**: Comprehensive non-developer friendly mockup viewing guide
- **Documentation**: Quick start instructions for accessing app mockups
- **README**: Step-by-step mockup navigation guide for stakeholders

### Enhanced
- **Mobile Mockups**: Improved responsive design system for better cross-device compatibility
- **User Experience**: Better touch targets and mobile-first responsive design

## [0.1.0] - 2024-09-10

### Added
- **Mobile Mockups**: Complete responsive phone mockup system with sleek scaling
- **Design System**: Comprehensive UI system with interactive tooling
- **UI Components**: Advanced interactions and dark mode support
- **Navigation**: Improved spacing and visual hierarchy with vibrant borders
- **Mockup System**: Interactive phone frame with multiple screen demonstrations
- **Theme System**: Dark/light mode toggle with persistent storage
- **Responsive Design**: Mobile-first approach with clamp() sizing functions
- **Animation System**: Smooth transitions and micro-interactions

### Infrastructure
- **Project Setup**: Initial monorepo structure with backend and mobile directories
- **Build System**: Basic development environment with CSS/JS organization
- **Documentation**: Foundational README and project structure documentation
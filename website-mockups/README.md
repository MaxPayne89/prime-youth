# Prime Youth - Website Mockups

Modern, mobile-first website mockups for Prime Youth afterschool activities platform.

## Overview

This project contains responsive website mockups converted from the original app designs, featuring a sleek, modern interface built with Tailwind CSS and Alpine.js.

## Features

### Design System
- **Colors**: Brand colors (Cyan #00CED1, Magenta #FF1493, Yellow #FFD700)
- **Typography**: Inter font for modern, readable text
- **Components**: Rounded corners, glass morphism effects, gradient backgrounds
- **Mobile-first**: Optimized for 375px mobile screens

### Screens Implemented

#### 1. Login Screen
- Glass morphism login form with gradient background
- Email/password fields with floating labels
- Social login options (Google, Facebook)
- Animated logo with gentle bounce effect
- "Sign In" submits to home screen

#### 2. Home Screen
- Profile header with gradient background
- Children cards with progress bars and activity pills
- Quick action buttons with hover effects
- Recent achievements section
- Bottom navigation for easy access

#### 3. Programs Screen
- Search functionality with filter pills
- Program cards with:
  - Hero images and availability indicators
  - Pricing and schedule information
  - Feature badges and action buttons
- Call-to-action section for consultations
- Load more functionality

#### 4. Activity Detail Screen
- Hero section with back navigation
- Program information overlay
- Comprehensive program details
- Instructor profile with ratings
- Parent testimonials
- Enrollment section with pricing

### Technical Stack

- **HTML5**: Semantic markup structure
- **Tailwind CSS 3.4+**: Utility-first CSS framework via CDN
- **Alpine.js**: Lightweight reactive framework for interactivity
- **Google Fonts**: Inter font family
- **Mobile-first responsive design**

### Interactive Features

- Screen navigation with smooth transitions
- Hover effects on buttons and cards
- Form validation ready
- Filter functionality (UI implemented)
- Progress bars with calculated percentages
- Star ratings display
- Mock data integration via Alpine.js

## Getting Started

### Quick Start
1. Open `index.html` in a modern web browser
2. Use the navigation tabs at the top to switch between screens
3. Test on mobile devices using browser dev tools

### Development Setup
If you want to use the build system:
```bash
npm install
npm run build-css  # Build and watch for changes
```

### File Structure
```
website-mockups/
├── index.html              # Main mockup file
├── package.json            # Tailwind CSS dependencies
├── tailwind.config.js      # Tailwind configuration
├── assets/
│   └── images/            # Image assets
└── README.md              # This file
```

## Design Highlights

### Modern UI Elements
- **Glass Morphism**: Frosted glass effect on login form
- **Gradient Backgrounds**: Brand color gradients throughout
- **Rounded Corners**: Modern 2xl border radius
- **Micro-interactions**: Hover and focus states
- **Progressive Enhancement**: Works without JavaScript

### Mobile Optimization
- Touch-friendly button sizes (min 44px)
- Optimized spacing and typography
- Responsive images and layouts
- Fixed bottom navigation
- Swipe-friendly horizontal scrolling

### Brand Integration
- Consistent use of Prime Youth brand colors
- Professional yet playful design approach
- Child-friendly visual elements
- Parent-focused information architecture

## Browser Support

- Chrome/Edge 88+
- Firefox 85+
- Safari 14+
- Mobile browsers with modern CSS support

## Next Steps

### Planned Enhancements
- Desktop responsive breakpoints
- Advanced filtering functionality
- Form submission handling
- Real API integration
- Performance optimizations

### Phoenix LiveView Integration
These mockups are designed to be easily converted to Phoenix LiveView components:
- Component-based structure
- Data-driven content
- Event handling patterns
- Server-side rendering friendly

## Contributing

When making changes:
1. Follow mobile-first design principles
2. Use existing color and spacing tokens
3. Maintain accessibility standards
4. Test on multiple devices
5. Update this README as needed

## Notes

- Images use Unsplash for mockup purposes
- All data is currently mock data
- Transitions and animations use CSS/Tailwind
- Forms are presentation-only (no backend)
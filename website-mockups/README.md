# Prime Youth - Website Mockups

Modern, responsive website mockups for Prime Youth afterschool activities platform with mobile, tablet, and desktop optimizations.

## Overview

This project contains responsive website mockups converted from the original app designs, featuring a sleek, modern interface built with Tailwind CSS and Alpine.js. Includes a view mode switcher to preview mobile, tablet, and desktop layouts from a single file.

## Features

### Responsive Design System
- **Colors**: Brand colors (Cyan #00CED1, Magenta #FF1493, Yellow #FFD700)
- **Typography**: Inter font with responsive sizing
- **Components**: Rounded corners, glass morphism effects, gradient backgrounds
- **Multi-device**: Mobile (375px), Tablet (768px), Desktop (1280px+) optimized
- **View Switcher**: Toggle between device views from the same interface

### Screens Implemented

#### 1. Login Screen
**Mobile**: Centered form with gradient background and glass morphism
**Desktop**: Split layout with branding showcase (left) and clean form (right)
- Email/password fields with responsive styling
- Social login options (Google, Facebook)
- Animated logo with gentle bounce effect
- Feature highlights on desktop branding side

#### 2. Home Screen
**Mobile**: Single-column layout with bottom navigation
**Desktop**: Grid layouts and enhanced spacing
- Profile header with gradient background
- Children cards in responsive grid (2 columns desktop, 1 mobile)
- Quick actions grid (4 columns desktop, 2 mobile)
- Recent achievements section
- Responsive navigation (bottom mobile, integrated desktop)

#### 3. Programs Screen
**Mobile**: Single-column program cards
**Desktop**: 3-column grid layout with enhanced filters
- Search functionality with responsive filter pills
- Program cards with:
  - Hero images and availability indicators
  - Pricing and schedule information
  - Feature badges and action buttons
- Responsive grid layout (3 columns desktop, 2 tablet, 1 mobile)
- Call-to-action section for consultations

#### 4. Activity Detail Screen
**Mobile**: Single-column scrolling layout
**Desktop**: Two-column layout with sticky sidebar
- Hero section with back navigation
- Program information overlay
- Main content (left): descriptions, instructor info, testimonials
- Sidebar (right): sticky enrollment card with pricing
- Responsive typography and spacing

### Technical Stack

- **HTML5**: Semantic markup structure
- **Tailwind CSS 3.4+**: Utility-first CSS framework via CDN
- **Alpine.js**: Lightweight reactive framework for interactivity
- **Google Fonts**: Inter font family
- **Mobile-first responsive design**

### Interactive Features

- **View Mode Switcher**: Toggle between Mobile/Tablet/Desktop views
- Screen navigation with smooth transitions
- Responsive layouts that adapt to selected view mode
- Hover effects on buttons and cards
- Form validation ready
- Filter functionality (UI implemented)
- Progress bars with calculated percentages
- Star ratings display
- Mock data integration via Alpine.js
- Sticky elements on desktop (sidebar, navigation)

## Getting Started

### Quick Start
1. Open `index.html` in a modern web browser
2. Use the **view mode switcher** (top-right) to toggle between Mobile/Tablet/Desktop
3. Use the navigation tabs to switch between screens (Login/Home/Programs/Activity Detail)
4. Test responsive behavior by switching view modes
5. All features work without any setup - just open and view!

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

## Recent Updates (Desktop Optimization)

### ✅ Completed Features
- **Multi-device View Switcher**: Toggle between Mobile (375px), Tablet (768px), and Desktop (1280px+)
- **Responsive Login**: Split-screen desktop layout with branding showcase
- **Grid-based Home**: 2-column children cards, 4-column quick actions on desktop
- **3-column Programs**: Desktop grid with responsive filters and enhanced spacing
- **Sidebar Detail Page**: Two-column layout with sticky enrollment sidebar
- **Adaptive Navigation**: Bottom nav (mobile) transitions to integrated navigation (desktop)
- **Enhanced Typography**: Responsive text sizes and spacing for optimal readability
- **Improved UX**: Sticky elements, hover states, and smooth transitions

## Next Steps

### Planned Enhancements
- Advanced filtering functionality
- Form submission handling
- Real API integration
- Performance optimizations
- Additional breakpoint fine-tuning

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
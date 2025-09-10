# Prime Youth Mobile Mockups

This directory contains HTML/CSS mockups for the Prime Youth mobile application, designed to serve as a reference implementation for the Kotlin Multiplatform Mobile development.

## Overview

These mockups implement a complete design system based on the Prime Youth brand identity, featuring:

- **Brand Colors**: Yellow (#FFD700), Magenta (#FF1493), Cyan (#00CED1)
- **Mobile-First Design**: Optimized for touch interfaces and small screens
- **Native Feel**: Follows iOS and Android design patterns
- **Component-Based**: Modular CSS that maps to KMP shared UI components
- **Accessibility**: WCAG compliant with proper focus states and semantic HTML

## Files Structure

```
mockups/
├── index.html           # Main mockup file with all screens
├── styles/
│   ├── base.css        # Design system foundations & variables
│   ├── components.css  # Reusable UI components
│   └── screens.css     # Screen-specific layouts
└── README.md           # This documentation
```

## Design System

### Brand Colors

The color palette is derived from the Prime Youth logo:

```css
--color-yellow: #FFD700;    /* Primary accent - buttons, highlights */
--color-magenta: #FF1493;   /* Secondary accent - notifications, status */
--color-cyan: #00CED1;      /* Tertiary accent - links, active states */
```

### Typography

- **Primary Font**: System fonts (-apple-system, BlinkMacSystemFont, Segoe UI)
- **Font Scale**: 12px (xs) to 40px (4xl) with consistent line heights
- **Font Weights**: Light (300) to Bold (700)

### Spacing System

Based on 4px increments for consistent rhythm:

```css
--space-xs: 4px;     /* Tight spacing */
--space-sm: 8px;     /* Small spacing */
--space-md: 16px;    /* Default spacing */
--space-lg: 24px;    /* Large spacing */
--space-xl: 32px;    /* Extra large spacing */
--space-2xl: 48px;   /* Section spacing */
--space-3xl: 64px;   /* Page spacing */
```

### Component Architecture

The CSS is organized into three layers:

1. **base.css** - Design tokens, reset, typography, utilities
2. **components.css** - Reusable UI components (buttons, cards, forms)
3. **screens.css** - Screen-specific layouts and compositions

## Key Components

### Buttons

- `.btn-primary` - Yellow primary actions
- `.btn-secondary` - Cyan secondary actions  
- `.btn-outline` - Ghost/outline style
- `.btn-icon` - Icon-only buttons

### Cards

- `.card` - Basic card container
- `.activity-card` - Activity list items
- `.activity-card-large` - Detailed activity cards

### Navigation

- `.bottom-nav` - Tab bar navigation
- `.app-header` - Screen headers with actions

### Forms

- Touch-friendly 48px minimum height
- Focus states with brand colors
- Validation states built-in

## Screen Mockups

### 1. Login Screen
- Prime Youth logo and branding
- Clean form layout
- Authentication links

### 2. Home Screen  
- Welcome message with user name
- Quick actions grid (3 columns)
- Upcoming activities list
- Activity recommendations carousel
- Bottom tab navigation

### 3. Activities Screen
- Filter chips for categories
- Activity cards with images
- Instructor information
- Pricing and availability
- Enrollment buttons

### 4. Profile Screen
- User avatar and information
- Activity statistics
- Children management
- Account settings
- Support links

## Mobile Responsiveness

The design supports three main breakpoints:

- **Default**: 428px (iPhone 14 Pro Max)
- **Medium**: 375px (iPhone SE)
- **Small**: 320px (Older devices)

## Touch Targets

All interactive elements meet accessibility guidelines:

- **Minimum size**: 44x44px (48px for primary actions)
- **Spacing**: 8px minimum between touch targets
- **Visual feedback**: Hover and active states

## Implementation Notes for KMP

### Shared Components

The CSS components map directly to KMP shared UI components:

```kotlin
// Example mapping
class PrimaryButton : CommonComponent {
    // Implement .btn-primary styles
}

class ActivityCard : CommonComponent {
    // Implement .activity-card styles  
}
```

### Color System

Define the brand colors as shared resources:

```kotlin
object PrimeYouthColors {
    val Yellow = Color(0xFFFFD700)
    val Magenta = Color(0xFFFF1493) 
    val Cyan = Color(0xFF00CED1)
    // ... neutral colors
}
```

### Typography Scale

Create a shared typography system:

```kotlin
object PrimeYouthTypography {
    val headingLarge = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.SemiBold)
    val headingMedium = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
    // ... additional styles
}
```

### Layout System

The spacing system translates to:

```kotlin
object PrimeYouthSpacing {
    val xs = 4.dp
    val sm = 8.dp  
    val md = 16.dp
    val lg = 24.dp
    val xl = 32.dp
}
```

## Usage

1. Open `index.html` in a web browser
2. Use the navigation buttons to switch between screens
3. Resize the browser to test responsive behavior
4. Inspect elements to see the CSS structure

## Browser Testing

Recommended testing:

- **Chrome/Safari**: Primary testing browsers
- **Firefox**: Secondary testing
- **Mobile Safari**: iOS testing
- **Chrome Mobile**: Android testing

## Future Enhancements

Planned additions:

- Dark mode color scheme
- Animation specifications
- Component interaction states
- Loading states and skeletons
- Error state designs

## Contributing

When updating these mockups:

1. Maintain the existing color system
2. Follow the spacing scale
3. Test across all breakpoints
4. Update this README with changes
5. Consider KMP implementation impact

## Questions?

For questions about the design system or implementation guidance, please refer to the project documentation or create an issue in the repository.
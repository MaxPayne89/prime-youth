# Frontend Architecture

## Component Organization

- Core UI components in `lib/klass_hero_web/components/core_components.ex`
- Feature-specific components organized by domain:
  - `ui_components.ex` - Basic UI elements (buttons, inputs, cards, badges, icons)
  - `composite_components.ex` - Complex composite components (search bars, filter pills, navigation)
  - `program_components.ex` - Domain-specific program components (program cards, hero sections, program lists)
  - `booking_components.ex` - Booking flow components (booking forms, time slot selection, capacity indicators)
  - `review_components.ex` - Review and rating components (star ratings, review lists, review forms)

## Design Principles

- **Mobile-first responsive design** - all UI elements designed for mobile before desktop
- Reusable component patterns with clear prop interfaces
- Consistent spacing and typography using Tailwind design tokens
- Tailwind CSS utility classes for styling

## Important Notes

- **Mobile-first design mandatory** - every design element must be designed mobile-first before desktop
- For "app wide" template imports, you can import/alias into the `klass_hero_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponents, and all modules that do `use KlassHeroWeb, :html`

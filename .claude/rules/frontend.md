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

## Typography

- **Always use `Theme.typography(:variant)`** for headings and display text in component/page templates — never raw `font-display` or `font-sans` on those elements
- Root/layout-level base font (e.g. `class="font-sans"` on `<body>` in `root.html.heex`) is allowed as a defense-in-depth default
- Available variants: `:hero`, `:page_title`, `:section_title`, `:cta`, `:card_title`, `:body`, `:body_small`, `:caption`
- Font configuration lives in `assets/css/app.css` (`@theme` block: `--font-sans`, `--font-display`) and `lib/klass_hero_web/components/theme.ex`
- Enforced by `mix lint_typography` in the precommit pipeline
- For justified exceptions, add `<%!-- typography-lint-ignore: reason --%>` on the line

## Important Notes

- **Mobile-first design mandatory** - every design element must be designed mobile-first before desktop
- For "app wide" template imports, you can import/alias into the `klass_hero_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponents, and all modules that do `use KlassHeroWeb, :html`

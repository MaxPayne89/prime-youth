# Founder Section on Homepage (#179)

## Summary

Add a "Built by Parents to Empower Educators" section to the homepage to build trust with parents.

## Placement

Between "Grow Your Passion Business" (muted bg) and FAQ (muted bg).

## Design

- **Background:** `Theme.bg(:surface)` — maintains alternating pattern
- **Container:** `max-w-7xl mx-auto` with `py-16 lg:py-24`, content constrained to `max-w-3xl` for reading width
- **Section ID:** `founder-section`
- **Layout:** Simple centered text block (no cards, no icons)

### Elements (top to bottom)

1. `.section_label` — "Our Story"
2. `<h2>` — "Built by Parents to Empower Educators." with `Theme.typography(:page_title)` + `Theme.text_color(:heading)`
3. `<p>` — Body copy from issue, `text-lg` + `Theme.text_color(:secondary)`, `leading-relaxed`
4. CTA — `<.link navigate={~p"/about"}>` styled as gradient button (`Theme.gradient(:primary)`) with "Read our founding story" + arrow

### Implementation

Inline in `home_live.ex` template — no new component needed. One-off section like the others.

### Testing

- Section renders with heading and body text
- CTA links to `/about`

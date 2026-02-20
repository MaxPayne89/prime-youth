# Founding Story on About Page

GitHub issue: #180

## Changes

### 1. "Built for Berlin Families" — add paragraph

Add third `<p>` after existing two paragraphs:

> "We are Klass Hero — parents, brothers, and partners of educators — building the infrastructure that helps every child learn and thrive."

Same `text-lg text-hero-grey-700 leading-relaxed` styling.

### 2. Replace "Founding Team" with "The Klass Hero Story"

- **H2 title**: "The Klass Hero Story" — `font-display text-3xl md:text-4xl lg:text-5xl text-hero-black mb-4`
- **Subtitle**: "Built by Parents and Educators for More Learning Opportunities" — `text-lg text-hero-grey-700 max-w-3xl mx-auto`
- **Body**: 4 paragraphs continuous prose, `max-w-3xl mx-auto`, `text-lg text-hero-grey-700 leading-relaxed`, `mb-6` spacing
- **Background**: White (preserves alternating white/pink pattern)
- **Heading hierarchy**: H2 (not H1) to match page convention — single H1 remains "OUR MISSION"

Text content verbatim from issue #180 (Shane, Max connection, Konstantin, Laurie).

### 3. Cleanup

Remove `team_members/0` private function (unused after replacement).

### 4. Gettext

All new strings wrapped in `gettext()` for i18n.

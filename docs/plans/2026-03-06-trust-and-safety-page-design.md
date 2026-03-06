# Trust & Safety Page Design

**Issue:** #250
**Date:** 2026-03-06

## Overview

Static public Trust & Safety page to add legitimacy to the site by communicating Klass Hero's provider verification process and commitment to child safety. Follows the same LiveView pattern as About/Privacy Policy pages.

## Page Structure

Single LiveView module `TrustSafetyLive` with 5 sections, using direct HEEx template (like About page) with a data helper for the verification steps grid.

### Sections

1. **Hero** — `bg-hero-pink-50`, shield icon, title "TRUST & SAFETY", subtitle about platform foundation
2. **Commitment to Child Safety** — Two-column grid:
   - Left: heading, description, 4 checklist items in white cards with check icons
   - Right: accent card ("Vetted with Care") using `bg-hero-blue-600`
3. **6-Step Verification Process** — Data-driven via `verification_steps/0` helper, 3x2 responsive grid:
   1. Identity & Age Verification (`hero-identification`)
   2. Experience Validation (`hero-academic-cap`)
   3. Extended Background Checks (`hero-shield-check`)
   4. Video Screening (`hero-video-camera`)
   5. Child Safeguarding Training (`hero-heart`)
   6. Community Standards Agreement (`hero-check-circle`)
4. **Ongoing Quality & Accountability** — Dark card (`bg-gray-900`) with numbered list + suspension warning
5. **CTA** — `bg-hero-pink-50`, "Have Questions?" linking to `/contact`, closing tagline

### Navigation

- Desktop navbar: new link after Contact
- Mobile sidebar: new link after Contact
- Footer: new link after Terms of Service

### Route

```elixir
live "/trust-safety", TrustSafetyLive, :index
```

In `:public` live_session block.

### i18n

All strings wrapped in `gettext()`. German translations deferred (extracted via `mix gettext.extract`).

### Testing

Basic LiveView test verifying page renders, key sections present, navigation link works.

## Approach

Direct HEEx template (like About page) rather than data-driven sections (like Privacy Policy). The reference has 5 visually distinct sections that benefit from hand-crafted layouts. Only the verification steps grid uses a data helper.

## Content Alignment

Content overlap with About page's vetting section is out of scope — handled by follow-up issue #251.

## Files Changed

| File | Change |
|------|--------|
| `lib/klass_hero_web/live/trust_safety_live.ex` | New LiveView module |
| `lib/klass_hero_web/router.ex` | Add route to `:public` block |
| `lib/klass_hero_web/components/layouts/app.html.heex` | Nav links (desktop + mobile) |
| `lib/klass_hero_web/components/composite_components.ex` | Footer link |
| `test/klass_hero_web/live/trust_safety_live_test.exs` | New test file |

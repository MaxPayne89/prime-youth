# Hide Pricing Section on Homepage (#178)

## Goal

Hide the "Simple, Transparent Pricing" section on the homepage until transactions are live. Keep code in place for easy re-enablement.

## Changes

1. **Template** (`home_live.ex`, lines 297-444): Wrap entire pricing section in HEEx comment `<%!-- ... --%>`
2. **Tests** (`home_live_test.exs`): Add `@tag :skip` to all 7 pricing-related tests
3. **Leave in place**: `pricing_tab` assign in `mount/3`, `handle_event("switch_pricing_tab")`, `pricing_card` component — zero runtime cost, ready to uncomment

## Not Changing

- FAQ section
- Any other homepage sections
- Program catalog `pricing_period` fields (unrelated domain concept)

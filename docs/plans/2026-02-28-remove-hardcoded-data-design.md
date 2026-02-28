# Remove Hardcoded Data for Go-Live

## Goal

Remove all hardcoded/fake data from LiveViews and backend before go-live. Wire up existing backend capabilities, comment out features without backend support, and centralize contact info in application config.

## Strategy

**Bottom-up:** Delete fixture files first (`sample_fixtures.ex`, `mock_data.ex`), then resolve every compile error systematically. The compiler becomes the guide — nothing slips through.

## Decisions

| Decision | Choice |
|---|---|
| Contact info source | Application config (`config/config.exs`) with env var fallbacks |
| Features without backend | Comment out UI sections entirely |
| Features with existing backend | Wire up to real backend functions |
| Booking fees | Use program price + Enrollment fee calculator |
| Fixture files | Delete entirely (no move to test/support) |

## Changes by Category

### 1. Delete Fixture Files

- `lib/klass_hero_web/live/sample_fixtures.ex` — full module of fake programs, users, instructor, reviews, stats, contact info
- `lib/klass_hero_web/live/provider/mock_data.ex` — fake provider dashboard stats

### 2. Comment Out (No Backend Exists)

| LiveView | Section | Why |
|---|---|---|
| `program_detail_live.ex` | Instructor section | No instructor-as-domain-model; staff members exist but reviews context missing |
| `program_detail_live.ex` | Reviews section | No reviews/ratings context |
| `program_detail_live.ex` | Included items | No `included_items` field on Program schema |
| `dashboard_live.ex` | Achievements | No achievements context |
| `dashboard_live.ex` | Recommended programs | No recommendations feature |
| `dashboard_live.ex` | Referral stats (count/points) | No referral tracking system (code generation is real) |
| `provider/dashboard_live.ex` | Stats section | No analytics context |
| `about_live.ex` | Platform stats | No real metrics source |
| `booking_live.ex` | Bank transfer details (IBAN/BIC) | No payment config |

### 3. Wire Up Existing Backend

| LiveView | Hardcoded | Wire to |
|---|---|---|
| `programs_live.ex` | Static category filter list | `ProgramCatalog.program_categories/0` |
| `programs_live.ex` | `enrich_with_mock_data/1` | Remove; use real provider association data |
| `program_detail_live.ex` | `"Sept 1 - Oct 26"` | `ProgramPresenter.format_date_range/2` |
| `program_detail_live.ex` | `"Berlin"` | Provider location from association |
| `booking_live.ex` | `"Wednesdays 4-6 PM"` | `ProgramPresenter.format_schedule_brief/1` |
| `booking_live.ex` | `"Jan 15 - Mar 15, 2024"` | `ProgramPresenter.format_date_range_brief/1` |
| `booking_live.ex` | `@default_weekly_fee` etc. | `program.price_amount` + `Enrollment.FeeCalculator` |

### 4. Application Config (Contact Info)

Add to `config/config.exs`:
```elixir
config :klass_hero, :contact,
  email: "info@klasshero.com",
  phone: nil,
  address: nil
```

Consumers: `contact_live.ex`, `composite_components.ex` footer. Nil values → hide section.

### 5. Keep as Static Content

- `core_values/0`, `key_features/0` → move inline to `about_live.ex` (intentional marketing content)
- `office_hours/0`, `contact_subjects/0` → keep in `contact_live.ex` (intentional static content)
- `trending_searches.ex` → keep as-is (compile-time config, low severity)
- `program_presenter.ex` status `:active` default → keep (presenter default, not user-facing fake data)

### 6. Test Impact

- Update/remove tests referencing `SampleFixtures` or `MockData`
- Comment out tests for commented-out sections
- Update tests for wired-up features to use proper test fixtures

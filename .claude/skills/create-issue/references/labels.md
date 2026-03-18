# Label Taxonomy

Select labels from these categories. Always pick at least a type label.

## Type Labels

| Label | Use when |
|---|---|
| `bug` | Broken behavior, regression, incorrect output |
| `enhancement` | New functionality, missing feature, capability gap |
| `refactor` / `refactoring` | Code restructuring without behavior change |
| `design` | UI/UX design work |
| `documentation` | Docs-only changes |

**Note:** There is no `feature` label. Use `enhancement` for features.

## Area Labels

| Label | Use when |
|---|---|
| `backend` | Server-side Elixir/Phoenix code, domain logic, persistence |
| `mobile` | Mobile-specific UI or functionality |
| `admin-dashboard` | Admin panel features |
| `api` | API endpoints or external integrations |
| `docs` | Documentation files |

## Priority Labels

| Label | Use when |
|---|---|
| `priority:high` | Blocks other work, affects users, or is urgent |
| `priority:medium` | Important but not blocking |
| `priority:low` | Nice to have, no urgency |

Only apply if severity is clear from the finding. When in doubt, omit.

## Epic Labels (Strategic Initiatives)

| Label | Covers |
|---|---|
| `Provider Management` | Provider onboarding, verification, staff, incident reporting |
| `Marketplace Platform` | External providers, scalable marketplace model |
| `Job Board` | Parent-posted opportunities, custom requests |
| `Booking & Payments` | Invoices, waitlist, cross-sell, payment flows |
| `Program Operations` | Program filtering, attendance tracking, session management |
| `Platform Foundation` | i18n, GDPR, UI polish, infrastructure |

## Quality Labels

| Label | Use when |
|---|---|
| `code-quality` | Code quality improvements |
| `testing` | Test coverage gaps or test infrastructure |
| `automation` | CI/CD or automation improvements |
| `qa` | Quality assurance findings |

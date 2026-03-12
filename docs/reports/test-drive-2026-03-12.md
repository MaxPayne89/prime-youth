# Test Drive Report - 2026-03-12

## Scope
- Mode: branch (`feat/367-add-account-overview-to-admin-dashboard` vs `main`)
- Files changed: 10
- Routes affected: `/admin/accounts` (index), `/admin/accounts/:id/show`, `/admin/accounts/:id/edit`

## Backend Checks

### Passed
- `admin_update_changeset` silently drops `:name` from attrs — only `is_admin` appears in changes
- `admin_update_changeset` accepts `is_admin` toggle — changeset is valid
- `has_one` preloads work correctly — parent profile loaded, nil provider handled gracefully
- No warnings in application logs

## UI Checks

### Pages Tested
- `/admin/accounts` (index): PASS
  - Sidebar shows "Accounts" (not "Users")
  - Table columns: Email, Name, Roles, Subscription, Created At, Actions
  - Role badges render: Parent (blue), Provider (purple), Admin (red), dual-role combinations
  - Subscription badges render: Explorer, Starter, Professional, dual-tier
  - Em-dash shown for users without profiles (app@primeyouth.de)
  - No "New" button visible (creation disabled)
  - Self-edit prevention: own row shows only "Show" (no "Edit" button)
  - Pagination works (26 users, 15 per page, 2 pages)

- `/admin/accounts/:id/show`: PASS
  - Detail fields: Email, Name, Roles, Subscription, Created At
  - Badges render correctly on show view (Provider badge, Starter badge for Lena Hartmann)
  - Edit button present for non-self users

- `/admin/accounts/:id/edit`: PASS
  - Email field: disabled (readonly)
  - Name field: disabled (readonly)
  - Admin toggle: only editable field (checkbox)
  - Cancel and Save buttons present

- Self-edit prevention: PASS
  - Navigating to own edit URL raises `Backpex.ForbiddenError` with 403 status

- Mobile responsive (375x667): PASS
  - Backpex table collapses to Email + Actions columns
  - Sidebar collapses
  - No layout breaks

### Issues Found
None.

## Auto-Fixes Applied
None needed.

## Recommendations
None — all checks pass. Feature is ready for PR.

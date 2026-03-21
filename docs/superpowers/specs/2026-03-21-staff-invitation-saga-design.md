# Staff Invitation Saga Design

**Issue:** #492 — Adding a team member automatically sends them a provider registration email
**Date:** 2026-03-21
**Status:** Draft

## Overview

When a business account adds a staff member via the Team section, the platform automatically sends an invitation email. On completing registration, the staff member gets a `:staff_provider` role — they work under the inviting business's profile (no independent ProviderProfile). The flow is modeled as a choreography-based saga crossing the Provider and Accounts bounded contexts, with idempotency at every step and a compensating event for email delivery failure.

## Architecture: Choreography + Inline Saga State (Approach C)

Saga state lives on the `staff_members` table as `invitation_status`. No separate orchestrator or process manager. Each context reacts to the previous context's integration events. All saga events are **critical** (Oban-backed, idempotent via `processed_events` table).

This mirrors the existing Invite-Claim saga pattern (Enrollment ↔ Family).

A follow-up issue (#496) tracks extracting a reusable `GenStateMachine`-based process manager pattern once more sagas emerge.

## Saga Flow

### Happy Path — New User (no existing account)

```
Provider Context                          Accounts Context
──────────────────                        ──────────────────
Business owner adds staff member
  → CreateStaffMember use case
  → invitation_status: :pending
  → Emits :staff_member_invited (critical)
                                    ───►
                                          StaffInvitationHandler receives event
                                          → Generates invitation token (7-day expiry)
                                          → Stores hash on staff_members.invitation_token_hash
                                          → Sends invitation email via UserNotifier
                                          → Emits :staff_invitation_sent (critical)
                                    ◄───
Provider updates staff_member
  invitation_status: :sent

          ... user clicks link, completes registration ...

                                          Staff invitation registration LiveView
                                          → Registers user (intended_roles: [:staff_provider])
                                          → No ProviderProfile auto-created
                                          → Emits :staff_user_registered (critical)
                                    ◄───
Provider updates staff_member
  user_id: user.id
  invitation_status: :accepted
  → Saga complete
```

### Alternate Path — Existing User (already registered)

```
Provider Context                          Accounts Context
──────────────────                        ──────────────────
Business owner adds staff member
  → Detects email belongs to existing user
  → invitation_status: :pending
  → Emits :staff_member_invited (critical)
    payload includes existing_user_id
                                    ───►
                                          StaffInvitationHandler sees existing_user_id
                                          → Skips token generation & invitation email
                                          → Sends notification email instead
                                          → Emits :staff_user_registered (critical) immediately
                                    ◄───
Provider updates staff_member
  user_id: existing_user_id
  invitation_status: :accepted
  → Saga complete (fast path)
```

### Compensation Path — Email Delivery Failure

```
Provider Context                          Accounts Context
──────────────────                        ──────────────────
                                          Email delivery fails
                                          → Emits :staff_invitation_failed (critical)
                                    ◄───
Provider updates staff_member
  invitation_status: :failed
  (compensating event applied)

Business owner sees "Invitation Failed" in Team UI
  → Clicks "Resend Invite"
  → invitation_status transitions :failed → :pending
  → Clears old invitation_token_hash
  → Re-emits :staff_member_invited
  → Saga restarts from beginning (idempotent)
```

## Invitation Status State Machine

```
:pending ──→ :sent ──→ :accepted
    │           │
    │           └──→ :expired (via scheduled cleanup or on-access check)
    │
    └──→ :failed ──→ :pending (on resend)
```

Implemented as a pure domain function with a transition map on `StaffMember`:

```elixir
@valid_transitions %{
  nil     => [:pending],
  :pending => [:sent, :failed],
  :sent    => [:accepted, :expired],
  :failed  => [:pending]
}

def transition_invitation(staff_member, new_status) do
  allowed = Map.get(@valid_transitions, staff_member.invitation_status, [])

  if new_status in allowed do
    {:ok, %{staff_member | invitation_status: new_status}}
  else
    {:error, :invalid_invitation_transition}
  end
end
```

## Idempotency Guarantees

| Step | Guarantee |
|---|---|
| `:staff_member_invited` handled | Critical event + `processed_events` — handler runs exactly once |
| Token generation | If token already exists for this staff_member_id, skip |
| Email send | Idempotent by nature (worst case: duplicate email, not harmful) |
| `:staff_invitation_sent` / `:failed` | Critical event — status update is idempotent (re-setting same status is no-op) |
| `:staff_user_registered` handled | Critical event — linking same user_id twice is no-op |

## Data Model Changes

### Staff Members Table — New Columns

| Column | Type | Purpose |
|---|---|---|
| `user_id` | `references(:users, type: :binary_id, on_delete: :nilify_all)` | Links staff member to user account once registered/linked |
| `invitation_status` | `string` | Saga state: `pending`, `sent`, `failed`, `accepted`, `expired` |
| `invitation_token_hash` | `binary` | Hashed invitation token for secure lookup |

`on_delete: :nilify_all` preserves the staff member record if the user account is deleted (e.g., GDPR). The link is severed, invitation can be re-triggered.

Token hash lives on `staff_members` (not `user_tokens`) to co-locate saga state. Accounts performs a cross-context read to verify tokens.

### User Schema — Role Changes

- Add `:staff_provider` to valid roles in `UserRoles` type
- `intended_roles` at registration can now include `:staff_provider`

### Scope Enhancement

```elixir
%Scope{
  user: %User{},
  roles: [:staff_provider],
  parent: nil,
  provider: nil,
  staff_member: %StaffMember{}   # NEW — populated for :staff_provider role
}
```

`Scope.resolve_roles/1` gains a third check:

1. `Family.get_parent_by_identity(user.id)` → if found, add `:parent`
2. `Provider.get_provider_by_identity(user.id)` → if found, add `:provider`
3. `Provider.get_active_staff_member_by_user(user.id)` → if found, add `:staff_provider`, populate `scope.staff_member`

## Event Definitions

### Integration Events (Cross-Context, All Critical)

| Event | Source | Topic | Payload |
|---|---|---|---|
| `:staff_member_invited` | Provider | `integration:provider:staff_member_invited` | `{staff_member_id, provider_id, email, first_name, last_name, existing_user_id \| nil}` |
| `:staff_invitation_sent` | Accounts | `integration:accounts:staff_invitation_sent` | `{staff_member_id, provider_id}` |
| `:staff_invitation_failed` | Accounts | `integration:accounts:staff_invitation_failed` | `{staff_member_id, provider_id, reason}` |
| `:staff_user_registered` | Accounts | `integration:accounts:staff_user_registered` | `{user_id, staff_member_id, provider_id}` |

### Existing User Detection

Provider checks `Accounts.get_user_by_email/1` before emitting `:staff_member_invited`. If a user exists, `existing_user_id` is populated in the payload. This keeps the Accounts handler simple: branch on presence of `existing_user_id`.

### Registration Hook

The existing `ProviderEventHandler` that listens to `:user_registered` must skip ProviderProfile creation when `intended_roles` contains only `:staff_provider`.

## Routing & Role-Based Access

### New Router Scope

```elixir
live_session :require_staff_provider,
  on_mount: [{KlassHeroWeb.UserAuth, :require_staff_provider}] do
  live "/staff/dashboard", StaffDashboardLive, :index
end
```

`UserAuth` gets a `require_staff_provider` mount checking `:staff_provider in @current_scope.roles`.

### Staff Dashboard (Minimal for #492)

A new LiveView at `lib/klass_hero_web/live/staff/staff_dashboard_live.ex`:

- Shows the business name (via `staff_member.provider_id → ProviderProfile`)
- Lists programs matching staff member's `tags` (maps to program categories)
- No team management, billing, or verification docs

Full staff experience (schedule, attendance, messaging) is follow-up work.

## Email Templates

### Staff Invitation Email (new user)

- Function: `UserNotifier.deliver_staff_invitation/3`
- Subject: "You've been invited to join [Business Name] on Klass Hero"
- Body: Brief Klass Hero explanation, who invited them, tokenized registration link
- Link: `/users/staff-invitation/{token}`
- Plain text (consistent with existing emails)

### Staff Notification Email (existing user)

- Function: `UserNotifier.deliver_staff_added_notification/2`
- Subject: "You've been added to [Business Name]'s team on Klass Hero"
- Body: Explains they've been added, links to staff dashboard
- Link: `/staff/dashboard`

## Invitation Registration LiveView

New LiveView at `lib/klass_hero_web/live/user_live/staff_invitation.ex`, route: `/users/staff-invitation/:token`.

**On mount:**
1. Hash token from URL
2. Look up staff member via `invitation_token_hash` (cross-context read)
3. Not found or expired → error page
4. Found → pre-fill form with `first_name`, `last_name`, `email`

**On submit:**
1. Register via `Accounts.register_user/1` with `intended_roles: [:staff_provider]`
2. Emit `:staff_user_registered` integration event
3. Log in and redirect to `/staff/dashboard`

Lives in `:current_user` live session (no auth required).

## Token Generation

Same pattern as existing magic link tokens:

1. Generate 32 random bytes → URL-safe base64 encode (email link)
2. SHA-256 hash → store on `staff_members.invitation_token_hash`
3. Verify: hash URL token, query `staff_members` by hash + check `invitation_status == :sent`
4. Expiry: 7 days from creation

## Resend Flow

1. Business owner clicks "Resend Invite" (visible for `:failed` / `:expired` statuses)
2. `invitation_status` transitions back to `:pending`
3. Old `invitation_token_hash` cleared
4. Re-emits `:staff_member_invited` integration event
5. Saga restarts — fully idempotent

## Testing Strategy

### Unit Tests

**Provider Context:**
- `StaffMember.transition_invitation/2` — all valid transitions succeed, invalid transitions return error
- `CreateStaffMember` use case — emits `:staff_member_invited`, sets status `:pending`
- Existing user detection — payload includes `existing_user_id` when email matches
- Resend flow — transitions from `:failed`/`:expired` to `:pending`, clears token, re-emits event

**Accounts Context:**
- `StaffInvitationHandler` — happy path: token generated, email sent, `:staff_invitation_sent` emitted
- `StaffInvitationHandler` — failure path: email fails, `:staff_invitation_failed` emitted
- `StaffInvitationHandler` — existing user: notification sent, `:staff_user_registered` emitted immediately
- Token verification — valid token resolves staff member, expired/invalid rejected

**Shared:**
- Idempotency — each handler processes same event only once

### Integration Tests

**Full saga — new user:**
1. Create staff member → `:staff_member_invited` emitted
2. Handler processes → token created, email sent, `:staff_invitation_sent` emitted
3. Provider updates status to `:sent`
4. Register via token → user created with `:staff_provider` role
5. `:staff_user_registered` emitted → staff member linked, status `:accepted`
6. No ProviderProfile created

**Full saga — existing user:**
1. Create staff member with existing user's email → `existing_user_id` in payload
2. Handler sends notification, emits `:staff_user_registered`
3. Staff member linked immediately, status `:accepted`

**Compensation:**
1. Create staff member → email delivery fails
2. `:staff_invitation_failed` → status `:failed`
3. Resend → saga restarts from `:pending`

### LiveView Tests

**Staff Invitation Registration:**
- Valid token → form with pre-filled fields
- Expired token → error message
- Invalid token → error message
- Successful registration → redirect to `/staff/dashboard`

**Staff Dashboard:**
- Staff provider sees business name and assigned programs
- Programs filtered by staff member's tags

**Provider Team UI:**
- "Resend Invite" visible for `:failed` / `:expired`
- Invitation status displayed per staff member

## Related Issues

- #492 — Parent issue (this design)
- #496 — Follow-up: GenStateMachine-based saga process manager pattern

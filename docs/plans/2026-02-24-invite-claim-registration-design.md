# Design: Invite Claim & Auto-Registration

> **Context:** Enrollment | **Issue:** #176
> **Date:** 2026-02-24

## Purpose

When a guardian clicks the invite link from a bulk enrollment email, the system auto-registers them (or recognizes an existing account) and creates their child + enrollment — all without manual interaction beyond setting a password.

## Architecture: Event-Driven Choreography Saga

Three async steps, each triggered by the previous step's event. No context polls or queries another directly.

```
Step 1 (Sync — Web Layer)
  GET /invites/:token
  → validate token, fetch invite
  → check if guardian_email exists in Accounts
    → NEW USER:  create account (passwordless), generate magic link token
                  publish :invite_claimed
                  redirect to /users/log-in/:token
    → EXISTING:  publish :invite_claimed
                  redirect to /users/log-in with flash

Step 2a (Async — Enrollment Context)
  :invite_claimed → transition invite status: invite_sent → registered

Step 2b (Async — Family Context)
  :invite_claimed → create parent profile + child
  → publish :invite_family_ready {invite_id, user_id, child_id, parent_id}

Step 3 (Async — Enrollment Context)
  :invite_family_ready → create enrollment, transition invite: registered → enrolled
```

### Event Chain

```
invite_claimed ──→ Enrollment: status → registered
                ──→ Family: create parent + child ──→ invite_family_ready
                                                        ──→ Enrollment: create enrollment, status → enrolled
```

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Architecture | Event-driven choreography saga | Architectural purity, loose coupling between contexts |
| Consistency model | Eventually consistent | At current scale, events process in seconds; user is setting password during that time |
| Account creation | Passwordless (existing `register_user`) | Current auth is already magic-link based, no password in registration changeset |
| Post-claim UX (new user) | Redirect to `/users/log-in/:token` (existing magic link) | Reuses existing auth flow, zero custom UI |
| Post-claim UX (existing user) | Redirect to `/users/log-in` with flash | Security: invite link should not auto-log in existing accounts |
| Failure handling | Oban retry 3x, then `failed` status with error details | Covers transient failures; permanent failures surface to provider |
| Invite status ownership | All transitions inside Enrollment via events | Single context owns the lifecycle |
| Email copy | Add "set password in settings" note | User needs to know how to access account again |

## Web Layer: Invite Claim Endpoint

`GET /invites/:token` — Phoenix controller (no LiveView, just validate + redirect).

```
InviteClaimController.show(conn, %{"token" => token})
  │
  ├─ Fetch invite by token (Enrollment public API)
  │   ├─ Not found → redirect with flash "Invalid or expired link"
  │   ├─ Status not "invite_sent" → redirect with flash "This invite has already been used"
  │   └─ Found + valid → continue
  │
  ├─ Check if guardian_email exists in Accounts
  │   │
  │   ├─ EXISTS:
  │   │   ├─ Publish :invite_claimed {invite_id, existing_user_id, ...}
  │   │   └─ Redirect to /users/log-in with flash:
  │   │      "You already have an account. Log in to see your new enrollment."
  │   │
  │   └─ NEW:
  │       ├─ Accounts.register_user(email, name, role: :parent)
  │       ├─ Generate login token (existing magic link mechanism)
  │       ├─ Publish :invite_claimed {invite_id, new_user_id, ...}
  │       └─ Redirect to /users/log-in/:token
```

### `:invite_claimed` Event Payload

```elixir
%{
  invite_id: uuid,
  user_id: uuid,
  program_id: uuid,
  provider_id: uuid,
  is_new_user: boolean,
  child: %{
    first_name: string,
    last_name: string,
    date_of_birth: date,
    school_grade: integer | nil,
    school_name: string | nil,
    medical_conditions: string | nil,
    nut_allergy: boolean
  },
  guardian: %{
    first_name: string | nil,
    last_name: string | nil,
    email: string
  },
  consents: %{
    photo_marketing: boolean,
    photo_social_media: boolean
  }
}
```

## Family Context: `:invite_claimed` Handler

Handler lives in `Family.adapters.driven.events.event_handlers`.

```
Receive :invite_claimed
  → Check if parent profile exists for user_id
    → YES: reuse existing
    → NO: create from invite data (first_name, last_name)
  → Create child record:
      first_name, last_name, date_of_birth,
      school_grade, school_name,
      medical_conditions, nut_allergy,
      consent_photo_marketing, consent_photo_social_media
  → Link child to parent
  → Publish :invite_family_ready {invite_id, user_id, child_id, parent_id}
  → On failure: log (invite_id, user_id, step, error), Oban retries 3x
```

## Enrollment Context: Two Event Handlers

### Handler 1: `:invite_claimed` → Status Transition

```
Receive :invite_claimed
  → Fetch invite by invite_id
  → Transition: invite_sent → registered
  → Set registered_at timestamp
  → If already registered or beyond: skip (idempotent)
```

### Handler 2: `:invite_family_ready` → Create Enrollment

```
Receive :invite_family_ready {invite_id, user_id, child_id, parent_id}
  → Fetch invite
  → Create enrollment (program_id, child_id, parent_id)
  → Transition: registered → enrolled
  → Set enrolled_at timestamp
  → On failure: transition → failed with error details
```

## Email Template Change

Add to `InviteEmailNotifier` body:

> "After clicking the link below, your account will be created automatically. You can set a password in your account settings at any time."

## Error Handling

**Every handler logs at minimum:** `{invite_id, step_name, outcome}` for end-to-end traceability.

| Step | Failure Mode | Response |
|---|---|---|
| Web: token lookup | Not found / already used | Flash message, redirect. No event. |
| Web: account creation | Changeset error | Log invite_id + errors, render error |
| Enrollment: invite_claimed | Wrong status | Skip (idempotent), log warning |
| Family: invite_claimed | Parent/child creation fails | Log details, Oban retry 3x, then invite → failed |
| Enrollment: invite_family_ready | Enrollment creation fails | Log details, Oban retry 3x, then invite → failed |

**Permanent failure:** If Family handler fails permanently, `:invite_family_ready` never fires. Invite stays at `registered` with `failed` status. Provider sees failure with error details in enrollment list.

## Idempotency

Every handler is safe to re-run:

| Handler | Idempotency Strategy |
|---|---|
| Web: invite claim | Token already used (status not `invite_sent`) → redirect "already used" |
| Enrollment: invite_claimed | Already `registered` or beyond → skip |
| Family: invite_claimed | Parent exists → reuse. Child exists (same parent + name + DOB) → reuse, still publish event |
| Enrollment: invite_family_ready | Enrollment exists (unique partial index) → skip. Transition invite if not already `enrolled` |

## Out of Scope

- Custom "set password" page (reusing existing magic link + settings)
- Reminder emails for unclaimed invites
- Admin UI for retrying failed invites
- Chunked processing for large invite batches

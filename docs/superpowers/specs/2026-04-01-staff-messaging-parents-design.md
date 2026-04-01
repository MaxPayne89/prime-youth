# Staff Messaging Parents — Design Spec

**Issue:** #361 — Program-assigned providers can message parents alongside the business account
**Date:** 2026-04-01
**Status:** Draft

## Summary

Allow staff members assigned to a program to participate in message conversations with parents enrolled in that program. The business account retains full messaging access. Both parties see and can reply in the same thread. Parents see messages attributed to the provider brand with individual "via Person Name" attribution.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Join table location | Provider context | Staff assignment is a provider-side concern |
| Assignment granularity | Program-level | Matches issue language, conversations reference `program_id`. Session-level can be added later (nullable `program_session_id` column). |
| Assignment change behavior | Eager on assign, soft on unassign | Staff see existing threads immediately. Unassignment doesn't remove them from threads they contributed to. |
| Message attribution | Provider brand + "via Person Name" | Parents see the business identity; individual attribution in thread only. |
| Cross-context data flow | Integration events + Messaging projection | No ACL. Messaging stays self-contained for reads. |
| Staff conversation initiation | Reply only, no initiation | Business account controls the provider-parent relationship. |

## Data Model

### Provider Context — `program_staff_assignments` Table

```
program_staff_assignments
├── id (binary_id, PK)
├── provider_id (binary_id, FK → providers, NOT NULL)
├── program_id (binary_id, FK → programs, NOT NULL)
├── staff_member_id (binary_id, FK → staff_members, NOT NULL)
├── assigned_at (utc_datetime_usec, NOT NULL)
├── unassigned_at (utc_datetime_usec, nullable)
├── inserted_at, updated_at (timestamps)
```

**Constraints:**
- Unique index on `[program_id, staff_member_id]` where `unassigned_at IS NULL` (one active assignment per pair)
- `provider_id` denormalized for simpler queries

**Future extensibility:** A nullable `program_session_id` column can be added later for session-level assignment without breaking existing rows.

### Messaging Context — `program_staff_participants` Projection Table

```
program_staff_participants
├── id (binary_id, PK)
├── provider_id (binary_id, NOT NULL)
├── program_id (binary_id, NOT NULL)
├── staff_user_id (binary_id, NOT NULL)
├── active (boolean, default true)
├── inserted_at, updated_at (timestamps)
```

**Constraints:**
- Unique index on `[program_id, staff_user_id]`
- No foreign keys to Provider tables (projection, not source of truth)

Uses `staff_user_id` (not `staff_member_id`) because Messaging only deals in user identity.

### No Changes to Existing Tables

- `conversations` — no schema changes
- `conversation_participants` — no schema changes (staff added as regular `user_id` participants)
- `messages` — no schema changes (`sender_id` remains `user_id`)

## Event Flow

### Integration Events (Published by Provider)

| Event | Payload | Trigger |
|-------|---------|---------|
| `integration:provider:staff_assigned_to_program` | `%{provider_id, program_id, staff_member_id, staff_user_id, assigned_at}` | Staff assigned to program |
| `integration:provider:staff_unassigned_from_program` | `%{provider_id, program_id, staff_member_id, staff_user_id, unassigned_at}` | Staff unassigned from program |

`staff_user_id` included in payload so Messaging never needs to resolve staff_member → user.

### Messaging Event Handlers (Driving Adapters)

**On `staff_assigned_to_program`:**

1. Skip if `staff_user_id` is nil (staff hasn't accepted invitation yet)
2. Upsert `program_staff_participants` projection (set `active: true`)
3. Query active conversations for the program where staff user is not already a participant
4. Add staff user as participant to each conversation (with `joined_at: now`)
5. Update `conversation_summaries` projection for new participant rows

**On `staff_unassigned_from_program`:**

1. Update `program_staff_participants` projection (set `active: false`)
2. No removal from existing conversations (soft unassign — decision C)

### Conversation Creation — Consulting the Projection

**`CreateDirectConversation`:** After creating the conversation between business owner and parent, if the conversation has a program context (i.e., initiated from a program page), query `program_staff_participants` for active staff on that program. Add them as participants. Conversations without a program context (general inquiries) do not include staff.

**`BroadcastToProgram`:** After adding parent and provider participants, also add active assigned staff from the projection.

Both use a new driven port `ForResolvingProgramStaff` that queries the Messaging-owned projection table (internal read, not cross-context).

## Web Layer

### Routing

No new routes. Staff use the existing provider messaging routes:

- `/provider/messages` — `Provider.MessagesLive.Index`
- `/provider/messages/:id` — `Provider.MessagesLive.Show`

Staff are participants via `user_id`, so `MessagingLiveHelper` (which lists conversations by `user_id`) populates their inbox automatically.

### Message Attribution

Provider-side message bubbles display:
- **Primary:** Provider business name (e.g., "Sunshine Music Academy")
- **Secondary:** "via Sarah Miller"

Implemented via a `provider_user_ids` MapSet passed to the message component, resolved when loading the conversation. Simple set membership check per message — presentation concern only, no domain model changes.

### Conversation List (Summaries)

- **Parent rows:** `other_participant_name` = provider business name (parents see the brand)
- **Staff/owner rows:** `other_participant_name` = parent's name

No structural change to the `conversation_summaries` schema. Staff summary rows mirror existing business-owner logic.

### Staff Program Visibility

Self-filtering: staff are only added as participants to conversations for their assigned programs, so `list_conversations(user_id)` naturally returns only relevant conversations.

## Entitlements & Access Control

### No New Entitlement Functions

Staff inherit the business account's subscription tier. If the business can message, assigned staff can too. No separate staff entitlement checks.

### Send Message

- **Direct conversations:** Any participant can send. Staff are participants. No change.
- **Broadcasts:** Expand the "only provider can send" check from "is sender the provider owner" to "is sender a provider-side participant" using the same `provider_user_ids` set.

### Staff Cannot Initiate

Staff can reply in conversations they participate in but cannot create new direct conversations with parents. The business account remains the point of control. This is a simple guard: `CreateDirectConversation` checks the initiator is the provider owner, not just any provider-side user.

## Edge Cases

### Staff Without `user_id` (Pending Invitation)

Assignment events with `staff_user_id: nil` are skipped by the Messaging handler. When staff accepts invitation and gets a `user_id`, the Provider context re-publishes `staff_assigned_to_program` for all active assignments. Messaging handler is idempotent — duplicate events result in no-op upserts.

### Staff Deactivation

Provider publishes `staff_unassigned_from_program` for all active assignments. Soft unassign behavior applies. If reactivated and re-assigned, events fire again.

### Program Ends / Archived

Existing `ArchiveEndedProgramConversations` worker handles this. Staff are regular participants — archival affects them like everyone else. The `program_staff_participants` projection is low-cost; no eager cleanup needed.

### GDPR / Account Deletion

Existing `AnonymizeUserData` use case handles staff deletion — anonymizes messages, marks participations as left. Works because staff are regular `user_id` participants.

### Race Conditions

Concurrent assignment + conversation creation: both paths may try to add the same staff user. The unique constraint on `[conversation_id, user_id]` in `conversation_participants` and `:already_participant` handling make this safe (harmless no-op).

## What NOT To Do

| Avoid | Why |
|-------|-----|
| Don't add `staff_member_id` to `conversation_participants` | Participants are user-identity-based. Mixing in staff identity creates two ways to identify the same person. |
| Don't query Provider tables from Messaging | Use the projection. Keep Messaging self-contained. |
| Don't remove staff from conversations on unassign | They may have replied. Removing orphans messages with no visible sender. |
| Don't make the projection the source of truth | Provider owns assignments. Projection can be rebuilt from events. |
| Don't publish events before DB transaction commits | Use after-commit callbacks (existing pattern). |
| Don't create separate staff messaging routes | Staff use the same provider messaging views. |
| Don't add participant role to DB schema | It's a presentation concern derivable from context. |
| Don't show staff names to parents in conversation list | Parents see the provider brand. Individual attribution only in the thread. |
| Don't create staff-specific entitlement tiers | Staff inherit business account capabilities. |
| Don't let staff initiate new conversations | Business account controls the provider-parent relationship. |
| Don't block assignment if staff has no `user_id` | Assignment is valid before invitation acceptance. Skip messaging side until they have a user. |
| Don't eagerly clean up projection on program end | Low-cost data; avoids edge cases with reopened programs. |
| Don't try to order events to avoid races | Idempotent handlers + unique constraints are simpler and more robust. |

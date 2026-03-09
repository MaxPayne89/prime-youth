# Send Individual Message from Roster

**Issue:** #318 — Add send individual message icon
**Date:** 2026-03-08

## Context

Providers want to message individual parents directly from the roster modal on the dashboard. The roster modal (in `provider_components.ex`) currently shows enrolled children with status and enrollment date. The messaging system (`CreateDirectConversation` use case) already supports creating/finding direct 1-on-1 conversations.

## Design

### 1. Data Layer — Extend Roster Entry

**File:** `lib/klass_hero/enrollment/application/use_cases/list_program_enrollments.ex`

Add `parent_id` and `parent_user_id` to each roster entry. The enrollment model already has `parent_id` (parent profile ID). To get `parent_user_id` (accounts user ID), resolve via a new ACL port.

Final entry shape:

```elixir
%{
  enrollment_id: String.t(),
  child_id: String.t(),
  child_name: String.t(),
  parent_id: String.t(),
  parent_user_id: String.t(),
  status: atom(),
  enrolled_at: DateTime.t()
}
```

### 2. Cross-Context ACL — Parent Profile Resolution

**New port:** `ForResolvingParentInfo` behavior in the Enrollment context.

- Method: `get_parents_by_ids([parent_id]) :: [%{id, identity_id}]`
- Adapter: Queries `parents` table for `id` and `identity_id`
- Config: Wired under `:enrollment` in `config.exs`

Follows the same pattern as existing `ForResolvingChildInfo`.

### 3. Component Layer — Message Column

**File:** `lib/klass_hero_web/components/provider_components.ex`

Add a 4th column to `enrolled_tab` table with a message icon button per row.

Button states (consistent with broadcast button disabled pattern from PR #324):

| Condition | State | Title |
|-----------|-------|-------|
| Provider is starter tier | Disabled | "Upgrade to Professional" |
| Enrollment not confirmed | Disabled | "Enrollment not confirmed" |
| Both pass | Enabled | "Send Message" |

Fires `send_message_to_parent` event with `phx-value-parent-user-id`.

New assign on `roster_modal`: `can_message?` (boolean).

### 4. LiveView Event Handler

**File:** `lib/klass_hero_web/live/provider/dashboard_live.ex`

- `view_roster`: compute `can_message?` via `Entitlements.can_initiate_messaging?(scope)` and assign it
- New `handle_event("send_message_to_parent")`:
  1. Extract `parent_user_id` from params
  2. Call `Messaging.create_direct_conversation(scope, provider_id, parent_user_id)`
  3. On `{:ok, conversation}` → `push_navigate` to `/provider/messages/#{conversation.id}`
  4. On `{:error, _}` → flash error

### 5. Testing

- `ListProgramEnrollments` unit test: verify entries include `parent_id` and `parent_user_id`
- `dashboard_live_test.exs`:
  - Message button visible and enabled for confirmed enrollments
  - Message button disabled for non-confirmed enrollments
  - Message button disabled for starter tier providers
  - Clicking enabled button navigates to messaging page
- No migration needed

## Decisions

- **Multiple children, same parent:** Each row gets its own button. `CreateDirectConversation` is idempotent (find-or-create), so duplicate clicks open the same conversation.
- **Navigation:** Clicking navigates away from roster modal to `/provider/messages/:conversation_id`. No inline compose.
- **Entitlement gating:** Computed once on roster open, all buttons disabled if provider can't message.
- **Disabled pattern:** Consistent with PR #324 broadcast button (greyed out icon, `cursor-not-allowed`, title attribute).

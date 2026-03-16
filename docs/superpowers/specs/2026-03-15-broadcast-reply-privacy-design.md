# Broadcast Reply Privacy — Design Spec

**Issue:** [#425](https://github.com/MaxPayne89/klass-hero/issues/425)
**Date:** 2026-03-15
**Status:** Draft

## Problem

Parents can reply to broadcast messages (`type: :program_broadcast`), and those
replies are visible to all other parents in the conversation. This is a privacy
breach — broadcast conversations were designed as one-way announcements from
provider to enrolled parents.

**Root cause:** `SendMessage` only checks participant status, not conversation
type. The UI always renders the message input regardless of conversation type.

## Solution

Three coordinated changes:

1. **Server-side guard** in `SendMessage` — reject messages from non-provider
   users in broadcast conversations
2. **New `ReplyPrivatelyToBroadcast` use case** — orchestrates creating a direct
   conversation with the provider and inserting a context system message
3. **UI swap** — replace the message input with a "Reply privately" button for
   parents viewing broadcast conversations

### 1. SendMessage Guard

Add a validation step after `verify_participant` in `SendMessage.execute/4`:

- Fetch the conversation via conversation repo `get_by_id/1`
- If `conversation.type == :program_broadcast`, resolve the provider's user ID
  via `ForResolvingUsers.get_user_id_for_provider/1` (new port callback) using
  the conversation's `provider_id` (which is the provider *profile* ID, not the
  user ID)
- If `sender_id` does not match the resolved provider user ID, return
  `{:error, :broadcast_reply_not_allowed}`
- Provider continues to send freely (follow-up announcements)
- Update `SendMessage` `@spec` to include `:broadcast_reply_not_allowed` in
  error return types

This is defense in depth — even if the UI hides the input, the event could be
crafted.

**New port callback:** Add `get_user_id_for_provider/1` to
`ForResolvingUsers` behaviour. The `UserResolver` adapter implements it by
querying `SELECT identity_id FROM providers WHERE id = ?`. This follows the
existing anti-corruption layer pattern (e.g., `ForQueryingEnrollments`).

### 2. ReplyPrivatelyToBroadcast Use Case

**Location:** `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex`

**Parameters:** `scope` (`Scope.t()`) and `broadcast_conversation_id` (string)

**Steps:**

1. Receive `scope` and `broadcast_conversation_id`
2. Fetch the broadcast conversation → get `provider_id` and `subject`
3. Resolve the provider's user ID via `ForResolvingUsers.get_user_id_for_provider/1`
4. Call `CreateDirectConversation.execute/3` with `skip_entitlement_check: true`
   to find or create a direct conversation with that provider. The `scope`
   parameter is passed through from the caller.
5. Send a system message into the direct conversation using the parent's user ID
   (`scope.user.id`) as `sender_id`. Content uses a structured format:
   `"[broadcast:CONVERSATION_ID] Re: SUBJECT"` — the `[broadcast:ID]` prefix
   is a machine-parseable token for idempotency dedup, kept outside any
   Gettext-translated portion. Uses `SendMessage.execute/4` with
   `message_type: :system`. This is safe because `CreateDirectConversation`
   synchronously adds both parties as participants before returning, so the
   parent is already a participant.
6. Return `{:ok, direct_conversation_id}`
7. If the broadcast conversation is not found (archived or deleted), return
   `{:error, :not_found}` (passthrough from `get_by_id`)

**Entitlement bypass:** `CreateDirectConversation.execute/3` currently takes
`(scope, provider_id, target_user_id)` with no opts. Add a 4th `opts \\ []`
parameter. When `skip_entitlement_check: true` is passed, skip the
`check_entitlement/1` call. This opt is only used by internal use case callers
— the public facade `Messaging.create_direct_conversation/3` does not expose it.

**Idempotency:**

- If a direct conversation already exists with the provider, reuse it
  (existing `CreateDirectConversation` behavior)
- System note is only inserted if no existing `:system` type message in the
  direct conversation contains the `[broadcast:CONVERSATION_ID]` token. Query
  via message repo with `message_type: :system` filter + content pattern match.
  The embedded ID enables reliable dedup even when multiple broadcasts share
  the same subject. If the parent has already been chatting in the direct
  conversation, a new system note is still desirable — it re-establishes the
  broadcast context for the provider.

### 3. UI Changes

**`messaging_components.ex` — `message_area/1`:**

Add `conversation` and `variant` as new parameters to the private `message_area/1`
function (currently it only receives `streams`, `messages_empty?`, `form`,
`current_user_id`, `sender_names`). Both values are available in the calling
`conversation_show/1` component but need to be explicitly threaded through.

Conditional rendering:

```
cond do
  variant == :provider -> <.message_input>
  conversation.type == :program_broadcast -> <.broadcast_reply_bar>
  true -> <.message_input>
end
```

**New `broadcast_reply_bar/1` component:**

- DOM ID: `id="broadcast-reply-bar"`
- Same bottom-pinned position as message input
- Brief note: "Broadcast messages are one-way"
- "Reply privately" button with primary action styling
- Button triggers `phx-click="reply_privately"` LiveView event

**`MessagingLiveHelper.__using__(:show)`:**

Injects `handle_event("reply_privately", ...)`:

1. Calls `Messaging.reply_privately_to_broadcast(scope, conversation_id)`
2. On `{:ok, direct_conversation_id}` → `push_navigate` to the direct
   conversation. Path uses `socket.assigns.back_path` base to determine the
   correct route prefix (`/messages/:id` for parents, `/provider/messages/:id`
   for providers)
3. On error → flash message

### Facade

Expose on `KlassHero.Messaging`:

```elixir
@spec reply_privately_to_broadcast(Scope.t(), String.t()) ::
        {:ok, String.t()} | {:error, term()}
defdelegate reply_privately_to_broadcast(scope, broadcast_conversation_id),
  to: ReplyPrivatelyToBroadcast,
  as: :execute
```

## Testing

### SendMessage Guard

- Parent sending to broadcast → `{:error, :broadcast_reply_not_allowed}`
- Provider sending to own broadcast → success
- Existing direct conversation tests unchanged

### ReplyPrivatelyToBroadcast Use Case

- Creates direct conversation with provider, inserts system note
- Reuses existing direct conversation if one exists
- Idempotent — no duplicate system notes on repeated calls
- Works regardless of subscription tier

### ForResolvingUsers Port

- `get_user_id_for_provider/1` returns `{:ok, user_id}` for valid provider
- Returns `{:error, :not_found}` for invalid provider ID

### LiveView

- Parent on broadcast: no `#message-form`, sees `#broadcast-reply-bar`
- Provider on broadcast: sees `#message-form`, no `#broadcast-reply-bar`
- Parent clicks "Reply privately": navigates to direct conversation
- Parent on direct conversation: sees `#message-form` as usual

## Files Changed

| File | Change |
|------|--------|
| `lib/klass_hero/messaging/application/use_cases/send_message.ex` | Add broadcast send guard, fetch conversation |
| `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex` | **New** — orchestrate private reply flow |
| `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex` | Add `opts \\ []` 4th param, `skip_entitlement_check` support |
| `lib/klass_hero/messaging/domain/ports/for_resolving_users.ex` | Add `get_user_id_for_provider/1` callback |
| `lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex` | Implement `get_user_id_for_provider/1` |
| `lib/klass_hero/messaging.ex` | Expose `reply_privately_to_broadcast/2` on facade, update `send_message` spec |
| `lib/klass_hero_web/components/messaging_components.ex` | Conditional input/reply-bar, new `broadcast_reply_bar/1` |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | Inject `reply_privately` event handler, pass conversation + variant to message_area |
| `test/klass_hero/messaging/application/use_cases/send_message_test.exs` | Broadcast guard tests |
| `test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs` | **New** — use case tests |
| `test/klass_hero_web/live/messaging_live_helper_test.exs` | LiveView integration tests for reply bar + navigation |

## Out of Scope

- Threading / quoting specific messages
- Notification preferences for broadcasts
- Tier-based entitlement enforcement for private replies (deferred — all tiers
  allowed for now)

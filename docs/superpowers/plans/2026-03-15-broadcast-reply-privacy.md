# Broadcast Reply Privacy Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent parents from replying to broadcast messages in a way visible to other parents; offer a "Reply privately" button that creates a direct conversation with the provider instead.

**Architecture:** Three coordinated changes following existing Messaging DDD/Ports & Adapters patterns: (1) server-side guard in `SendMessage` use case, (2) new `ReplyPrivatelyToBroadcast` use case for private reply orchestration, (3) UI conditional rendering in `messaging_components.ex`.

**Tech Stack:** Elixir/Phoenix, Ecto, LiveView, ExMachina (tests)

**Spec:** `docs/superpowers/specs/2026-03-15-broadcast-reply-privacy-design.md`

**Skills:** @superpowers:test-driven-development (TDD — write failing tests first, then implement), @idiomatic-elixir (pattern matching, `with` chains, guard clauses)

**Tools:** Use Tidewave MCP (`project_eval`, `get_docs`, `execute_sql_query`, `get_source_location`) for interactive verification during implementation. Prefer Tidewave over bash for any Elixir evaluation, documentation lookup, or database inspection.

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/klass_hero/messaging/domain/ports/for_resolving_users.ex` | Add `get_user_id_for_provider/1` callback |
| `lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex` | Implement provider→user resolution |
| `lib/klass_hero/messaging/application/use_cases/send_message.ex` | Add broadcast send guard |
| `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex` | Add `opts` param for entitlement bypass |
| `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex` | **New** — orchestrate private reply |
| `lib/klass_hero/messaging.ex` | Expose new use case on facade |
| `lib/klass_hero_web/components/messaging_components.ex` | Conditional input/reply-bar |
| `lib/klass_hero_web/live/messaging_live_helper.ex` | Inject `reply_privately` event handler |

---

## Chunk 1: Port, Adapter, and SendMessage Guard

### Task 1: Add `get_user_id_for_provider/1` to ForResolvingUsers port

**Files:**
- Modify: `lib/klass_hero/messaging/domain/ports/for_resolving_users.ex:37`
- Modify: `lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex:40`
- Test: `test/klass_hero/messaging/adapters/driven/accounts/user_resolver_test.exs` (new or existing)

- [ ] **Step 1: Write the failing test for `get_user_id_for_provider/1`**

Create or extend `test/klass_hero/messaging/adapters/driven/accounts/user_resolver_test.exs`:

```elixir
defmodule KlassHero.Messaging.Adapters.Driven.Accounts.UserResolverTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Accounts.UserResolver

  describe "get_user_id_for_provider/1" do
    test "returns user_id for a valid provider profile ID" do
      user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: user.id)

      user_id = user.id
      assert {:ok, ^user_id} = UserResolver.get_user_id_for_provider(provider.id)
    end

    test "returns not_found for a non-existent provider ID" do
      assert {:error, :not_found} =
               UserResolver.get_user_id_for_provider(Ecto.UUID.generate())
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/adapters/driven/accounts/user_resolver_test.exs -v`
Expected: FAIL — `get_user_id_for_provider/1` is undefined

- [ ] **Step 3: Add callback to port**

In `lib/klass_hero/messaging/domain/ports/for_resolving_users.ex`, add before the closing `end`:

```elixir
@doc """
Gets the user ID (identity_id) for a provider profile.

Used to resolve the provider_id stored on conversations (which is the
provider profile ID) back to the user ID for permission checks.

## Parameters
- provider_id: The provider profile ID

## Returns
- `{:ok, user_id}` - The user ID for this provider
- `{:error, :not_found}` - No provider exists with this ID
"""
@callback get_user_id_for_provider(provider_id :: String.t()) ::
            {:ok, String.t()} | {:error, :not_found}
```

- [ ] **Step 4: Implement in UserResolver adapter**

In `lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex`, add before the closing `end`. Note: the adapter already imports `Ecto.Query` and aliases `Repo`. Add the provider schema alias at the top:

```elixir
alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
```

Then the implementation:

```elixir
@impl true
@spec get_user_id_for_provider(String.t()) :: {:ok, String.t()} | {:error, :not_found}
def get_user_id_for_provider(provider_id) do
  case Repo.one(
         from(p in ProviderProfileSchema,
           where: p.id == ^provider_id,
           select: p.identity_id
         )
       ) do
    nil -> {:error, :not_found}
    identity_id -> {:ok, identity_id}
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/klass_hero/messaging/adapters/driven/accounts/user_resolver_test.exs -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/domain/ports/for_resolving_users.ex \
  lib/klass_hero/messaging/adapters/driven/accounts/user_resolver.ex \
  test/klass_hero/messaging/adapters/driven/accounts/user_resolver_test.exs
git commit -m "feat(messaging): add get_user_id_for_provider to ForResolvingUsers port"
```

---

### Task 2: Add broadcast send guard to SendMessage

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/send_message.ex:38-56`
- Test: `test/klass_hero/messaging/application/use_cases/send_message_test.exs`

- [ ] **Step 1: Write failing tests for broadcast guard**

Add to `test/klass_hero/messaging/application/use_cases/send_message_test.exs` inside the existing `describe "execute/4"` block:

```elixir
test "rejects message from parent in broadcast conversation" do
  # Create provider with a known user
  provider_user = AccountsFixtures.user_fixture()
  provider = insert(:provider_profile_schema, identity_id: provider_user.id)

  # Create broadcast conversation owned by provider
  program = insert(:program_schema)

  broadcast =
    insert(:conversation_schema,
      type: "program_broadcast",
      provider_id: provider.id,
      program_id: program.id,
      subject: "Announcement"
    )

  # Parent is a participant but should not be able to send
  parent_user = AccountsFixtures.user_fixture()

  insert(:participant_schema,
    conversation_id: broadcast.id,
    user_id: parent_user.id
  )

  assert {:error, :broadcast_reply_not_allowed} =
           SendMessage.execute(broadcast.id, parent_user.id, "My reply")
end

test "allows provider to send in their own broadcast conversation" do
  provider_user = AccountsFixtures.user_fixture()
  provider = insert(:provider_profile_schema, identity_id: provider_user.id)
  program = insert(:program_schema)

  broadcast =
    insert(:conversation_schema,
      type: "program_broadcast",
      provider_id: provider.id,
      program_id: program.id,
      subject: "Announcement"
    )

  insert(:participant_schema,
    conversation_id: broadcast.id,
    user_id: provider_user.id
  )

  assert {:ok, message} =
           SendMessage.execute(broadcast.id, provider_user.id, "Follow-up!")

  assert message.content == "Follow-up!"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/application/use_cases/send_message_test.exs -v`
Expected: The first new test passes (because currently no guard exists — the message goes through), and the second also passes. Wait — the first test should currently PASS (no guard), so we need to verify the test asserts the right thing. Actually the first test expects `{:error, :broadcast_reply_not_allowed}` but currently gets `{:ok, message}`, so it FAILS. Good.

- [ ] **Step 3: Implement the broadcast guard**

Modify `lib/klass_hero/messaging/application/use_cases/send_message.ex`:

Update the `@spec` to include `:broadcast_reply_not_allowed`:

```elixir
@spec execute(String.t(), String.t(), String.t(), keyword()) ::
        {:ok, KlassHero.Messaging.Domain.Models.Message.t()}
        | {:error, :not_participant | :broadcast_reply_not_allowed | term()}
```

Update `execute/4` to add the guard between participant check and message creation:

```elixir
def execute(conversation_id, sender_id, content, opts \\ []) do
  message_type = Keyword.get(opts, :message_type, :text)
  repos = Repositories.all()

  with :ok <- verify_participant(conversation_id, sender_id, repos.participants),
       :ok <- verify_broadcast_send_permission(conversation_id, sender_id, repos),
       {:ok, message} <-
         create_message(conversation_id, sender_id, content, message_type, repos.messages) do
    update_sender_read_status(conversation_id, sender_id, repos.participants)
    publish_event(message)

    Logger.info("Message sent",
      message_id: message.id,
      conversation_id: conversation_id,
      sender_id: sender_id
    )

    {:ok, message}
  end
end
```

Add the private function:

```elixir
# Trigger: sender is trying to post in a broadcast conversation
# Why: broadcast conversations are one-way — only the provider can send.
#      Parents replying would expose their messages to all other parents (privacy breach).
# Outcome: non-provider senders are rejected; direct conversations pass through unchanged.
defp verify_broadcast_send_permission(conversation_id, sender_id, repos) do
  case repos.conversations.get_by_id(conversation_id) do
    {:ok, %{type: :program_broadcast, provider_id: provider_id}} ->
      case repos.users.get_user_id_for_provider(provider_id) do
        {:ok, ^sender_id} -> :ok
        {:ok, _other_user_id} -> {:error, :broadcast_reply_not_allowed}
        {:error, :not_found} -> {:error, :broadcast_reply_not_allowed}
      end

    {:ok, _direct_conversation} ->
      :ok

    {:error, :not_found} ->
      {:error, :not_found}
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/application/use_cases/send_message_test.exs -v`
Expected: ALL tests PASS (including existing ones)

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `mix test --max-failures 5`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/send_message.ex \
  test/klass_hero/messaging/application/use_cases/send_message_test.exs
git commit -m "fix(messaging): block non-provider replies in broadcast conversations

Adds server-side guard to SendMessage use case that rejects messages
from non-provider users in program_broadcast conversations.
Defense in depth for #425."
```

---

## Chunk 2: CreateDirectConversation opts + ReplyPrivatelyToBroadcast use case

### Task 3: Add `opts` parameter to CreateDirectConversation for entitlement bypass

**Files:**
- Modify: `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex:39-46`
- Test: `test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs` (existing)

- [ ] **Step 1: Write failing test for entitlement bypass**

Add to the existing test file (find or create `test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs`):

```elixir
test "skips entitlement check when skip_entitlement_check: true" do
  # Build a scope that would normally fail entitlement check (starter tier parent)
  provider = insert(:provider_profile_schema)
  user = AccountsFixtures.user_fixture()
  target_user = AccountsFixtures.user_fixture()

  scope = %KlassHero.Accounts.Scope{
    user: user,
    roles: [:parent],
    parent: %KlassHero.Family.Domain.Models.ParentProfile{
      id: Ecto.UUID.generate(),
      identity_id: user.id,
      subscription_tier: :explorer
    },
    provider: nil
  }

  # Without bypass, this would return {:error, :not_entitled}
  assert {:ok, conversation} =
           KlassHero.Messaging.Application.UseCases.CreateDirectConversation.execute(
             scope,
             provider.id,
             target_user.id,
             skip_entitlement_check: true
           )

  assert conversation.type == :direct
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs -v`
Expected: FAIL — `execute/4` doesn't exist (only `execute/3`)

- [ ] **Step 3: Add opts parameter**

In `lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex`:

Update `@spec` and function head:

```elixir
@spec execute(Scope.t(), String.t(), String.t(), keyword()) ::
        {:ok, KlassHero.Messaging.Domain.Models.Conversation.t()}
        | {:error, :not_entitled | term()}
def execute(%Scope{} = scope, provider_id, target_user_id, opts \\ []) do
  with :ok <- maybe_check_entitlement(scope, opts) do
    find_or_create_conversation(scope, provider_id, target_user_id)
  end
end
```

Add `maybe_check_entitlement/2` — keeps original `check_entitlement/1` and delegates to it:

```elixir
# Trigger: skip_entitlement_check opt is set
# Why: ReplyPrivatelyToBroadcast use case allows all tiers to reply
#      privately — the provider initiated contact via broadcast.
# Outcome: entitlement check is skipped, conversation creation proceeds
defp maybe_check_entitlement(scope, opts) do
  if Keyword.get(opts, :skip_entitlement_check, false) do
    :ok
  else
    check_entitlement(scope)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs -v`
Expected: ALL tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/create_direct_conversation.ex \
  test/klass_hero/messaging/application/use_cases/create_direct_conversation_test.exs
git commit -m "feat(messaging): add skip_entitlement_check opt to CreateDirectConversation"
```

---

### Task 4: Create ReplyPrivatelyToBroadcast use case

**Files:**
- Create: `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex`
- Test: `test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs`

- [ ] **Step 1: Write the tests**

Create `test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs`:

```elixir
defmodule KlassHero.Messaging.Application.UseCases.ReplyPrivatelyToBroadcastTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Accounts.Scope
  alias KlassHero.AccountsFixtures
  alias KlassHero.Family.Domain.Models.ParentProfile
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository
  alias KlassHero.Messaging.Application.UseCases.ReplyPrivatelyToBroadcast

  describe "execute/2" do
    setup do
      # Create provider with known user
      provider_user = AccountsFixtures.user_fixture()
      provider = insert(:provider_profile_schema, identity_id: provider_user.id)
      program = insert(:program_schema)

      # Create broadcast conversation
      broadcast =
        insert(:conversation_schema,
          type: "program_broadcast",
          provider_id: provider.id,
          program_id: program.id,
          subject: "Schedule Change"
        )

      # Create parent with scope
      parent_user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: broadcast.id,
        user_id: parent_user.id
      )

      parent_profile = %ParentProfile{
        id: Ecto.UUID.generate(),
        identity_id: parent_user.id,
        subscription_tier: :explorer
      }

      scope = %Scope{
        user: parent_user,
        roles: [:parent],
        parent: parent_profile,
        provider: nil
      }

      %{
        scope: scope,
        broadcast: broadcast,
        provider: provider,
        provider_user: provider_user,
        parent_user: parent_user
      }
    end

    test "creates direct conversation with provider and inserts system note", ctx do
      assert {:ok, direct_conversation_id} =
               ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

      assert is_binary(direct_conversation_id)
      refute direct_conversation_id == ctx.broadcast.id

      # Verify system note was inserted
      {:ok, messages, _} =
        MessageRepository.list_for_conversation(direct_conversation_id, limit: 10)

      system_messages = Enum.filter(messages, &(&1.message_type == :system))
      assert length(system_messages) == 1

      note = hd(system_messages)
      assert note.content =~ "[broadcast:#{ctx.broadcast.id}]"
      assert note.content =~ "Schedule Change"
    end

    test "reuses existing direct conversation", ctx do
      assert {:ok, first_id} =
               ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

      assert {:ok, second_id} =
               ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

      assert first_id == second_id
    end

    test "is idempotent — no duplicate system notes on repeated calls", ctx do
      {:ok, conversation_id} =
        ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

      {:ok, ^conversation_id} =
        ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)

      {:ok, messages, _} =
        MessageRepository.list_for_conversation(conversation_id, limit: 50)

      system_messages = Enum.filter(messages, &(&1.message_type == :system))
      assert length(system_messages) == 1
    end

    test "works regardless of subscription tier (explorer parent)", ctx do
      # ctx.scope already has an explorer-tier parent (lowest tier)
      assert {:ok, _conversation_id} =
               ReplyPrivatelyToBroadcast.execute(ctx.scope, ctx.broadcast.id)
    end

    test "returns not_found for non-existent broadcast", ctx do
      assert {:error, :not_found} =
               ReplyPrivatelyToBroadcast.execute(ctx.scope, Ecto.UUID.generate())
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs -v`
Expected: FAIL — module does not exist

- [ ] **Step 3: Implement the use case**

Create `lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex`:

```elixir
defmodule KlassHero.Messaging.Application.UseCases.ReplyPrivatelyToBroadcast do
  @moduledoc """
  Use case for privately replying to a broadcast message.

  When a parent wants to respond to a broadcast, this use case:
  1. Fetches the broadcast conversation to get the provider
  2. Creates (or finds) a direct conversation with that provider
  3. Inserts a system message for context (idempotent)
  4. Returns the direct conversation ID for navigation
  """

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging.Application.UseCases.{CreateDirectConversation, SendMessage}
  alias KlassHero.Messaging.Repositories

  require Logger

  @doc """
  Orchestrates a private reply to a broadcast.

  ## Parameters
  - scope: The parent's scope
  - broadcast_conversation_id: The broadcast conversation being replied to

  ## Returns
  - `{:ok, direct_conversation_id}` - Direct conversation ready for messaging
  - `{:error, :not_found}` - Broadcast conversation not found
  - `{:error, reason}` - Other errors
  """
  @spec execute(Scope.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def execute(%Scope{} = scope, broadcast_conversation_id) do
    repos = Repositories.all()

    with {:ok, broadcast} <- repos.conversations.get_by_id(broadcast_conversation_id),
         {:ok, provider_user_id} <- repos.users.get_user_id_for_provider(broadcast.provider_id),
         {:ok, direct_conversation} <-
           CreateDirectConversation.execute(
             scope,
             broadcast.provider_id,
             provider_user_id,
             skip_entitlement_check: true
           ),
         :ok <-
           maybe_insert_system_note(
             direct_conversation,
             scope.user.id,
             broadcast,
             repos
           ) do
      Logger.info("Private reply to broadcast initiated",
        broadcast_id: broadcast_conversation_id,
        direct_conversation_id: direct_conversation.id,
        user_id: scope.user.id
      )

      {:ok, direct_conversation.id}
    end
  end

  # Trigger: parent initiates a private reply to a broadcast
  # Why: inserts a system note in the direct conversation so the provider
  #      knows which broadcast prompted the message. Dedup prevents duplicate
  #      notes if the parent taps "Reply privately" multiple times.
  # Outcome: exactly one system note per broadcast reference in the conversation
  defp maybe_insert_system_note(direct_conversation, sender_id, broadcast, repos) do
    token = "[broadcast:#{broadcast.id}]"

    if system_note_exists?(direct_conversation.id, token, repos.messages) do
      :ok
    else
      subject = broadcast.subject || "broadcast"
      content = "#{token} Re: #{subject}"

      case SendMessage.execute(direct_conversation.id, sender_id, content,
             message_type: :system
           ) do
        {:ok, _message} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp system_note_exists?(conversation_id, token, message_repo) do
    {:ok, messages, _} =
      message_repo.list_for_conversation(conversation_id, limit: 100)

    Enum.any?(messages, fn msg ->
      msg.message_type == :system and String.contains?(msg.content, token)
    end)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs -v`
Expected: ALL tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast.ex \
  test/klass_hero/messaging/application/use_cases/reply_privately_to_broadcast_test.exs
git commit -m "feat(messaging): add ReplyPrivatelyToBroadcast use case

Orchestrates creating a direct conversation with the broadcast's
provider and inserting an idempotent system note for context.
Bypasses entitlement check — all tiers can reply privately."
```

---

### Task 5: Expose on messaging facade

**Files:**
- Modify: `lib/klass_hero/messaging.ex:56`

- [ ] **Step 1: Add facade delegate**

In `lib/klass_hero/messaging.ex`, add the alias `ReplyPrivatelyToBroadcast` to the existing alias group (line 48-56), then add after the `broadcast_to_program` delegate:

```elixir
@doc """
Initiates a private reply to a broadcast message.

Creates (or finds) a direct conversation between the parent and the
broadcast's provider, inserts a context system message, and returns
the direct conversation ID for navigation.

## Parameters
- scope: The parent's scope
- broadcast_conversation_id: The broadcast being replied to

## Returns
- `{:ok, direct_conversation_id}` - Ready for messaging
- `{:error, :not_found}` - Broadcast not found
- `{:error, reason}` - Other errors

## Examples

    iex> Messaging.reply_privately_to_broadcast(scope, broadcast_id)
    {:ok, "direct-conversation-uuid"}

"""
@spec reply_privately_to_broadcast(Scope.t(), String.t()) ::
        {:ok, String.t()} | {:error, term()}
defdelegate reply_privately_to_broadcast(scope, broadcast_conversation_id),
  to: ReplyPrivatelyToBroadcast,
  as: :execute
```

Also update the `send_message` spec to include `:broadcast_reply_not_allowed`:

```elixir
@spec send_message(String.t(), String.t(), String.t(), keyword()) ::
        {:ok, Message.t()} | {:error, :not_participant | :broadcast_reply_not_allowed | term()}
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with zero warnings

- [ ] **Step 3: Run full test suite**

Run: `mix test --max-failures 5`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero/messaging.ex
git commit -m "feat(messaging): expose reply_privately_to_broadcast on facade"
```

---

## Chunk 3: UI Changes and LiveView Integration

### Task 6: Add broadcast_reply_bar component and conditional rendering

**Files:**
- Modify: `lib/klass_hero_web/components/messaging_components.ex:451-471`

- [ ] **Step 1: Add `broadcast_reply_bar/1` component**

In `lib/klass_hero_web/components/messaging_components.ex`, add the new component before the `# Helpers` comment (before line 473):

```elixir
@doc """
Renders the broadcast reply bar shown to parents viewing broadcast conversations.

Replaces the message input with a note that broadcasts are one-way
and a button to reply privately to the provider.
"""
def broadcast_reply_bar(assigns) do
  ~H"""
  <div
    id="broadcast-reply-bar"
    class={["p-4 border-t text-center", Theme.border_color(:light), Theme.bg(:surface)]}
  >
    <p class={["text-sm mb-3", Theme.text_color(:muted)]}>
      {gettext("Broadcast messages are one-way")}
    </p>
    <button
      phx-click="reply_privately"
      class={[
        "inline-flex items-center gap-2 px-6 py-2.5 bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700 transition-colors",
        Theme.rounded(:full)
      ]}
    >
      <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" />
      {gettext("Reply privately")}
    </button>
  </div>
  """
end
```

- [ ] **Step 2: Update `message_area/1` to accept conversation and variant**

Replace the existing `message_area/1` private function (lines 451-471) with:

```elixir
defp message_area(assigns) do
  ~H"""
  <div
    id="messages-container"
    class="flex-1 overflow-y-auto p-4 space-y-3"
    phx-hook="ScrollToBottom"
  >
    <div id="messages" phx-update="stream" class="space-y-3">
      <.message_bubble
        :for={{dom_id, message} <- @streams.messages}
        id={dom_id}
        message={message}
        is_own={MessagingLiveHelper.own_message?(message, @current_user_id)}
        sender_name={MessagingLiveHelper.get_sender_name(@sender_names, message.sender_id)}
      />
    </div>
    <.messages_empty_state :if={@messages_empty?} />
  </div>
  <%= cond do %>
    <% @variant == :provider -> %>
      <.message_input form={@form} />
    <% @conversation.type == :program_broadcast -> %>
      <.broadcast_reply_bar />
    <% true -> %>
      <.message_input form={@form} />
  <% end %>
  """
end
```

- [ ] **Step 3: Thread conversation and variant through from conversation_show/1**

Update both `conversation_show` clauses (parent and provider variants) to pass `conversation` and `variant` to `message_area`. In both clauses, change the `<.message_area>` call to include the new attrs:

For the parent variant (around line 413-419):

```heex
<.message_area
  streams={@streams}
  messages_empty?={@messages_empty?}
  form={@form}
  current_user_id={@current_user_id}
  sender_names={@sender_names}
  conversation={@conversation}
  variant={:parent}
/>
```

For the provider variant (around line 439-445):

```heex
<.message_area
  streams={@streams}
  messages_empty?={@messages_empty?}
  form={@form}
  current_user_id={@current_user_id}
  sender_names={@sender_names}
  conversation={@conversation}
  variant={:provider}
/>
```

- [ ] **Step 4: Verify compilation** (Steps 2 and 3 must both be applied before this — `message_area/1` references `@variant` and `@conversation` which are only passed through after Step 3)

Run: `mix compile --warnings-as-errors`
Expected: Compiles with zero warnings

- [ ] **Step 5: Commit**

```bash
git add lib/klass_hero_web/components/messaging_components.ex
git commit -m "feat(messaging-ui): add broadcast_reply_bar and conditional rendering

Parents viewing broadcast conversations see a 'Reply privately' button
instead of the message input. Providers keep the normal message input."
```

---

### Task 7: Inject reply_privately event handler in MessagingLiveHelper

**Files:**
- Modify: `lib/klass_hero_web/live/messaging_live_helper.ex:43-65`

- [ ] **Step 1: Add the event handler to the __using__(:show) macro**

In `lib/klass_hero_web/live/messaging_live_helper.ex`, add inside the `__using__(:show)` macro's `quote do` block (after the `handle_info` for `:messages_read`, before the closing `end`):

```elixir
@impl true
def handle_event("reply_privately", _params, socket) do
  MessagingLiveHelper.handle_reply_privately(socket)
end
```

- [ ] **Step 2: Add the handler function**

Add the public function after `handle_send_message/2` (after line 165):

```elixir
@doc """
Handles the reply_privately event for broadcast conversations.

Creates a direct conversation with the broadcast's provider and
navigates to it.
"""
def handle_reply_privately(socket) do
  scope = socket.assigns.current_scope
  conversation_id = socket.assigns.conversation.id
  back_path = socket.assigns.back_path

  case Messaging.reply_privately_to_broadcast(scope, conversation_id) do
    {:ok, direct_conversation_id} ->
      # Derive the conversation URL from the back_path
      # back_path is "/messages" or "/provider/messages"
      direct_path = "#{back_path}/#{direct_conversation_id}"

      {:noreply, push_navigate(socket, to: direct_path)}

    {:error, reason} ->
      Logger.error("Failed to create private reply",
        conversation_id: conversation_id,
        reason: inspect(reason)
      )

      {:noreply, put_flash(socket, :error, gettext("Could not start private conversation"))}
  end
end
```

- [ ] **Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with zero warnings

- [ ] **Step 4: Commit**

```bash
git add lib/klass_hero_web/live/messaging_live_helper.ex
git commit -m "feat(messaging): inject reply_privately event handler in LiveView helper"
```

---

### Task 8: LiveView integration tests

**Files:**
- Modify: `test/klass_hero_web/live/messages_live/show_test.exs`

- [ ] **Step 1: Add broadcast reply bar tests**

Add to `test/klass_hero_web/live/messages_live/show_test.exs` inside the existing `describe "broadcast conversations"` block:

```elixir
test "shows reply bar instead of message form for parent", %{conn: conn, user: user} do
  provider_user = AccountsFixtures.user_fixture()
  provider = insert(:provider_profile_schema, identity_id: provider_user.id)
  program = insert(:program_schema)

  broadcast =
    insert(:conversation_schema,
      type: "program_broadcast",
      provider_id: provider.id,
      program_id: program.id,
      subject: "Update"
    )

  insert(:participant_schema,
    conversation_id: broadcast.id,
    user_id: user.id
  )

  {:ok, view, _html} = live(conn, ~p"/messages/#{broadcast.id}")

  assert has_element?(view, "#broadcast-reply-bar")
  refute has_element?(view, "#message-form")
  assert has_element?(view, "button", "Reply privately")
end

test "shows message form for direct conversations", %{conn: conn, user: user} do
  conversation = insert(:conversation_schema)

  insert(:participant_schema,
    conversation_id: conversation.id,
    user_id: user.id
  )

  {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

  assert has_element?(view, "#message-form")
  refute has_element?(view, "#broadcast-reply-bar")
end

test "reply_privately navigates to direct conversation", %{conn: conn, user: user} do
  provider_user = AccountsFixtures.user_fixture()
  provider = insert(:provider_profile_schema, identity_id: provider_user.id)
  program = insert(:program_schema)

  broadcast =
    insert(:conversation_schema,
      type: "program_broadcast",
      provider_id: provider.id,
      program_id: program.id,
      subject: "Update"
    )

  insert(:participant_schema,
    conversation_id: broadcast.id,
    user_id: user.id
  )

  # Also add provider as participant (as BroadcastToProgram would)
  insert(:participant_schema,
    conversation_id: broadcast.id,
    user_id: provider_user.id
  )

  {:ok, view, _html} = live(conn, ~p"/messages/#{broadcast.id}")

  view
  |> element("#broadcast-reply-bar button", "Reply privately")
  |> render_click()

  # Should navigate to a new direct conversation
  {path, _flash} = assert_redirect(view)
  assert path =~ "/messages/"
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test test/klass_hero_web/live/messages_live/show_test.exs -v`
Expected: ALL tests PASS

- [ ] **Step 3: Run full test suite**

Run: `mix test --max-failures 5`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add test/klass_hero_web/live/messages_live/show_test.exs
git commit -m "test(messaging): add broadcast reply bar LiveView integration tests"
```

---

## Chunk 4: Final Verification

### Task 9: Precommit checks and push

- [ ] **Step 1: Run precommit**

Run: `mix precommit`
Expected: Compilation (zero warnings), format, and test suite all pass

- [ ] **Step 2: Push to remote**

```bash
git push -u origin bug/425-reply-to-broadcasts
```

- [ ] **Step 3: Verify push**

Run: `git status`
Expected: "Your branch is up to date with 'origin/bug/425-reply-to-broadcasts'"

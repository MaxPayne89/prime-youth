# Wallaby E2E Messaging Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add browser-driven E2E tests for messaging using Wallaby with a dedicated CI job that gates deployments.

**Architecture:** Wallaby drives headless Chrome sessions to test the full real-time messaging stack (PubSub → WebSocket → DOM). Multi-session tests verify that two users (provider + parent) see each other's messages in real-time. Tests run in a separate `test/e2e/` directory, excluded from `mix test` via `@moduletag :e2e`.

**Tech Stack:** Wallaby ~> 0.30, ChromeDriver, Phoenix.Ecto.SQL.Sandbox, ExUnit tags, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-03-26-wallaby-e2e-messaging-design.md`

---

## File Structure

| File | Responsibility |
|------|---------------|
| `mix.exs` | Add wallaby dep, update `elixirc_paths`, add `test.e2e` alias |
| `config/test.exs` | Wallaby config, `server: true`, `sql_sandbox: true` |
| `lib/klass_hero_web/endpoint.ex` | Conditional sandbox plug |
| `test/test_helper.exs` | Add `:e2e` to exclusion list |
| `test/e2e/support/e2e_case.ex` | ExUnit.CaseTemplate — sandbox + Wallaby lifecycle |
| `test/e2e/support/messaging_helpers.ex` | Thin helper — login, send_message, assertions |
| `test/e2e/messaging/broadcast_test.exs` | Scenarios 1-2 |
| `test/e2e/messaging/direct_message_test.exs` | Scenarios 3-4 |
| `test/e2e/messaging/conversation_list_test.exs` | Scenarios 5-6 |
| `test/e2e/messaging/mark_as_read_test.exs` | Scenario 7 |
| `lib/klass_hero_web/components/messaging_components.ex` | Add `data-role` test anchors |
| `.github/workflows/ci.yml` | Add `e2e` job |
| `bin/setup-chromedriver` | Local ChromeDriver installer script |

---

### Task 1: Add Wallaby Dependency

**Files:**
- Modify: `mix.exs:66` (deps list)

- [ ] **Step 1: Add wallaby to deps**

In `mix.exs`, add to the `deps` function after the `phoenix_test` line:

```elixir
{:wallaby, "~> 0.30", only: :test, runtime: false},
```

- [ ] **Step 2: Fetch dependencies**

Run: `mix deps.get`
Expected: Wallaby and its transitive deps download successfully.

- [ ] **Step 3: Compile**

Run: `MIX_ENV=test mix compile`
Expected: Clean compilation with no warnings.

- [ ] **Step 4: Commit**

```bash
git add mix.exs mix.lock
git commit -m "chore: add wallaby E2E testing dependency"
```

---

### Task 2: Configuration Changes

**Files:**
- Modify: `config/test.exs:16-20` (endpoint config)
- Modify: `config/test.exs` (append wallaby config)
- Modify: `lib/klass_hero_web/endpoint.ex:58-59` (before router plug)
- Modify: `test/test_helper.exs:1` (exclusion list)
- Modify: `mix.exs:46` (elixirc_paths)
- Modify: `mix.exs:124-148` (aliases)

- [ ] **Step 1: Enable server and add sandbox flag in config/test.exs**

Change `server: false` to `server: true` on line 20:

```elixir
# We run a server during test for Wallaby E2E browser tests
config :klass_hero, KlassHeroWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gY/oKuAYeC5ExhHrtu1JBwrpQdoGwtPOo3X9GdS7CFOnLe0eqRQ9w4cyV1MqvoYc",
  server: true
```

Add at the end of `config/test.exs`:

```elixir
# Wallaby E2E test configuration
config :wallaby,
  driver: Wallaby.Chrome,
  screenshot_on_failure: true,
  screenshot_dir: "tmp/e2e_screenshots",
  chrome: [headless: true],
  chromedriver: [path: System.get_env("CHROMEDRIVER_PATH", "_build/chromedriver/chromedriver")]

# Enable Ecto sandbox plug for Wallaby browser sessions
config :klass_hero, sql_sandbox: true
```

- [ ] **Step 2: Add sandbox plug to endpoint**

In `lib/klass_hero_web/endpoint.ex`, add before `plug KlassHeroWeb.Router` (line 59):

```elixir
if Application.compile_env(:klass_hero, :sql_sandbox) do
  plug Phoenix.Ecto.SQL.Sandbox
end
```

- [ ] **Step 3: Add :e2e to test exclusion list**

In `test/test_helper.exs`, change line 1:

```elixir
ExUnit.start(exclude: [:integration, :e2e], capture_log: true)
```

- [ ] **Step 4: Update elixirc_paths**

In `mix.exs`, change line 46:

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support", "test/e2e/support"]
```

- [ ] **Step 5: Add test.e2e alias**

In `mix.exs`, add to the `aliases` function (inside the keyword list, after `"test.watch"`):

```elixir
"test.e2e": ["test test/e2e --include e2e"],
```

- [ ] **Step 6: Verify compilation**

Run: `MIX_ENV=test mix compile --warnings-as-errors`
Expected: Clean compilation. The sandbox plug compiles conditionally, so no issues.

- [ ] **Step 7: Verify existing tests still pass**

Run: `mix test --max-failures 3`
Expected: All existing tests pass. The `server: true` change starts the HTTP server on port 4002 but doesn't affect `Phoenix.LiveViewTest` tests.

- [ ] **Step 8: Commit**

```bash
git add config/test.exs lib/klass_hero_web/endpoint.ex test/test_helper.exs mix.exs
git commit -m "feat: configure Wallaby E2E test infrastructure"
```

---

### Task 3: E2ECase Support Module

**Files:**
- Create: `test/e2e/support/e2e_case.ex`

- [ ] **Step 1: Create the E2ECase module**

```elixir
defmodule KlassHeroWeb.E2ECase do
  @moduledoc """
  ExUnit.CaseTemplate for browser-driven E2E tests using Wallaby.

  Handles:
  - Starting Wallaby (once per test module, lazily)
  - Ecto sandbox ownership with metadata for the sandbox plug
  - Common imports (Wallaby.DSL, factories, fixtures, helpers)

  All tests using this case are tagged `@moduletag :e2e` and excluded
  from regular `mix test` runs. Run with `mix test.e2e`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL

      import KlassHero.Factory
      import KlassHero.AccountsFixtures
      import KlassHeroWeb.E2E.MessagingHelpers

      @moduletag :e2e
    end
  end

  setup_all _context do
    {:ok, _} = Application.ensure_all_started(:wallaby)
    :ok
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(KlassHero.Repo, shared: not tags[:async])

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(KlassHero.Repo, pid)

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, sandbox_metadata: metadata}
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `MIX_ENV=test mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/support/e2e_case.ex
git commit -m "feat: add E2ECase ExUnit template for Wallaby tests"
```

---

### Task 4: MessagingHelpers Support Module

**Files:**
- Create: `test/e2e/support/messaging_helpers.ex`

- [ ] **Step 1: Create the MessagingHelpers module**

Key implementation details:
- Login navigates to `/users/log-in`, clicks "Or use password" to toggle to the password form, fills credentials, submits
- The password form ID is `login_form_password`, field IDs are `login_form_password_email` and `login_form_password_password`
- `valid_user_password()` returns `"hello world!"` — users must have `set_password/1` called in test setup
- The `send_message` form has `id="message-form"`, textarea has `id="message-input"`
- The send button needs a `data-role="send-message-btn"` attribute (added in Task 5)

```elixir
defmodule KlassHeroWeb.E2E.MessagingHelpers do
  @moduledoc """
  Thin helper layer for messaging E2E tests.

  Centralizes DOM selectors and common multi-step browser interactions
  so tests stay readable without premature Page Object abstraction.
  """

  use Wallaby.DSL

  @password "hello world!"

  @doc """
  Starts a new Wallaby browser session with Ecto sandbox metadata attached.

  The metadata allows the browser's HTTP requests to share the test
  process's database transaction via the Phoenix.Ecto.SQL.Sandbox plug.
  """
  def new_session(metadata) do
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    session
  end

  @doc """
  Logs in through the UI as the given user.

  Navigates to the login page, toggles to the password form,
  fills in credentials, and submits. The user must have had
  `AccountsFixtures.set_password/1` called on them.
  """
  def log_in(session, %{email: email}) do
    session
    |> visit("/users/log-in")
    |> click(Query.button("Or use password"))
    |> fill_in(Query.css("#login_form_password_email"), with: email)
    |> fill_in(Query.css("#login_form_password_password"), with: @password)
    |> click(Query.button("Log in and stay logged in"))
  end

  @doc """
  Sends a message in the current conversation view.

  Fills the message textarea and clicks the send button.
  """
  def send_message(session, text) do
    session
    |> fill_in(Query.css("#message-input"), with: text)
    |> click(Query.css("[data-role=send-message-btn]"))
  end

  @doc """
  Asserts that a message with the given text is visible in the conversation.
  """
  def assert_message_visible(session, text) do
    assert_has(session, Query.css("[data-role=message]", text: text))
  end

  @doc """
  Asserts the unread count badge shows the expected number.
  """
  def assert_unread_count(session, count) do
    assert_has(session, Query.css("[data-role=unread-count]", text: to_string(count)))
  end

  @doc """
  Asserts no unread count badge is visible.
  """
  def refute_unread_count(session) do
    refute_has(session, Query.css("[data-role=unread-count]"))
  end

  @doc """
  Navigates to the conversation list for the given role.
  """
  def visit_conversations(session, :provider), do: visit(session, "/provider/messages")
  def visit_conversations(session, :parent), do: visit(session, "/messages")

  @doc """
  Opens a conversation by clicking its card with matching text.
  """
  def open_conversation(session, name) do
    click(session, Query.css("[data-role=conversation-card]", text: name))
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `MIX_ENV=test mix compile --warnings-as-errors`
Expected: Clean compilation.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/support/messaging_helpers.ex
git commit -m "feat: add MessagingHelpers for E2E test interactions"
```

---

### Task 5: Template Data-Role Attributes

**Files:**
- Modify: `lib/klass_hero_web/components/messaging_components.ex:49-101` (conversation_card)
- Modify: `lib/klass_hero_web/components/messaging_components.ex:108-113` (unread_badge)
- Modify: `lib/klass_hero_web/components/messaging_components.ex:152-185` (message_bubble)
- Modify: `lib/klass_hero_web/components/messaging_components.ex:216-233` (message_input send button)

- [ ] **Step 1: Add data-role to conversation_card**

In `messaging_components.ex`, in the `conversation_card/1` function, add `data-role="conversation-card"` to the outer `<.link>` element (line 53):

```heex
<.link
  navigate={@navigate}
  id={@id}
  data-role="conversation-card"
  class={[
```

- [ ] **Step 2: Add data-role to unread_badge**

In the `unread_badge/1` function, add `data-role="unread-count"` to the `<span>` (line 110):

```heex
<span
  data-role="unread-count"
  class="inline-flex items-center justify-center min-w-5 h-5 px-1.5 text-xs font-semibold text-error-content bg-error rounded-full"
>
```

- [ ] **Step 3: Add data-role to message_bubble**

In the `message_bubble/1` function, add `data-role="message"` to the outer `<div>` (line 154):

```heex
<div id={@id} data-role="message" class={["flex", @is_own && "justify-end", !@is_own && "justify-start"]}>
```

- [ ] **Step 4: Add data-role to send button in message_input**

In the `message_input/1` function, add `data-role="send-message-btn"` to the submit `<button>` (line 217):

```heex
<button
  type="submit"
  disabled={@disabled}
  data-role="send-message-btn"
  class={[
```

- [ ] **Step 5: Verify compilation**

Run: `MIX_ENV=test mix compile --warnings-as-errors`
Expected: Clean compilation with no warnings.

- [ ] **Step 6: Verify existing tests still pass**

Run: `mix test test/klass_hero_web/live/messages_live/ test/klass_hero_web/live/provider/messages_live/ --max-failures 3`
Expected: All existing messaging LiveView tests pass — data attributes don't affect behavior.

- [ ] **Step 7: Commit**

```bash
git add lib/klass_hero_web/components/messaging_components.ex
git commit -m "feat: add data-role test anchors to messaging components"
```

---

### Task 6: Broadcast E2E Test — Provider Broadcasts, Parent Sees It (Scenario 1)

**Files:**
- Create: `test/e2e/messaging/broadcast_test.exs`

This is the first E2E test. Getting it green validates the entire Wallaby + sandbox + PubSub + LiveView stack.

- [ ] **Step 1: Write the broadcast test file with scenario 1**

Reference docs for test data setup:
- `test/support/fixtures/accounts_fixtures.ex` — `user_fixture/1`, `set_password/1`, `valid_user_password/0`
- `test/support/factory.ex` — `:provider_profile_schema`, `:parent_profile_schema`, `:program_schema`, `:enrollment_schema`, `insert_child_with_guardian/1`
- Provider needs `subscription_tier: "professional"` (factory default)
- Parent needs `subscription_tier: "active"` (factory default is `"explorer"`, override it)
- `Messaging.broadcast_to_program/4` is triggered through the broadcast form UI at `/provider/programs/:program_id/broadcast`

```elixir
defmodule KlassHeroWeb.E2E.Messaging.BroadcastTest do
  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope

  describe "broadcast messaging" do
    setup %{sandbox_metadata: metadata} do
      # Create provider with password
      provider_user = user_fixture(%{intended_roles: [:provider]})
      provider_user = set_password(provider_user)

      provider =
        insert(:provider_profile_schema,
          identity_id: provider_user.id,
          subscription_tier: "professional"
        )

      # Create parent with password and active tier for messaging
      parent_user = user_fixture(%{intended_roles: [:parent]})
      parent_user = set_password(parent_user)

      parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create child linked to parent
      {_child, _parent_schema} = insert_child_with_guardian(parent: parent)

      # Create program owned by provider
      program = insert(:program_schema, provider_id: provider.id)

      # Create enrollment linking parent to program
      insert(:enrollment_schema,
        program_id: program.id,
        parent_id: parent.id,
        child_id: hd(KlassHero.Repo.preload(parent, :children).children).id,
        status: "confirmed"
      )

      # Start browser sessions
      provider_session = new_session(metadata)
      parent_session = new_session(metadata)

      # Log in both users
      provider_session = log_in(provider_session, provider_user)
      parent_session = log_in(parent_session, parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        provider_user: provider_user,
        parent_user: parent_user,
        program: program
      }
    end

    test "provider broadcasts message and parent sees it in real-time", %{
      provider_session: provider_session,
      parent_session: parent_session,
      program: program
    } do
      # Parent navigates to conversation list
      parent_session = visit_conversations(parent_session, :parent)

      # Provider sends broadcast
      provider_session
      |> visit("/provider/programs/#{program.id}/broadcast")
      |> fill_in(Query.css("#content"), with: "Field trip tomorrow at 9am!")
      |> click(Query.button("Send Broadcast"))

      # Parent should see the broadcast message appear
      parent_session
      |> assert_has(Query.css("[data-role=conversation-card]", text: "Field trip tomorrow at 9am!"))
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it works**

Run: `mix test.e2e --max-failures 1`
Expected: PASS. If it fails, debug by checking:
- Is chromedriver installed? Run `bin/setup-chromedriver` first (Task 12).
- Check sandbox metadata is wiring correctly.
- Check PubSub is delivering events (Oban runs inline in test).

Note: The enrollment factory setup may need adjustment depending on FK constraints. If `insert(:enrollment_schema, ...)` fails because it tries to create its own program/child, pass all required IDs explicitly so it doesn't use the factory defaults.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/messaging/broadcast_test.exs
git commit -m "test: add E2E test for provider broadcast to parent"
```

---

### Task 7: Broadcast Private Reply E2E Test (Scenario 2)

**Files:**
- Modify: `test/e2e/messaging/broadcast_test.exs`

- [ ] **Step 1: Add scenario 2 to the describe block**

The broadcast reply bar has a "Reply privately" button with `phx-click="reply_privately"`. When clicked, it creates a new private conversation and redirects the parent there.

```elixir
test "parent replies privately to broadcast and provider sees private conversation", %{
  provider_session: provider_session,
  parent_session: parent_session,
  program: program
} do
  # Provider sends broadcast first
  provider_session
  |> visit("/provider/programs/#{program.id}/broadcast")
  |> fill_in(Query.css("#content"), with: "Reminder: bring sunscreen")
  |> click(Query.button("Send Broadcast"))

  # Wait for provider to be redirected to the broadcast conversation
  assert_has(provider_session, Query.css("[data-role=message]", text: "Reminder: bring sunscreen"))

  # Parent opens the broadcast conversation
  parent_session
  |> visit_conversations(:parent)
  |> open_conversation("Reminder: bring sunscreen")

  # Parent clicks "Reply privately"
  parent_session
  |> click(Query.button("Reply privately"))

  # Parent is now in a private conversation — send a reply
  parent_session
  |> send_message("Should we also bring lunch?")

  # Provider navigates to their conversation list and sees the private reply
  provider_session
  |> visit_conversations(:provider)
  |> assert_has(Query.css("[data-role=conversation-card]", text: "Should we also bring lunch?"))
end
```

- [ ] **Step 2: Run the test**

Run: `mix test.e2e --max-failures 1`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/messaging/broadcast_test.exs
git commit -m "test: add E2E test for private reply to broadcast"
```

---

### Task 8: Direct Message E2E Tests (Scenarios 3-4)

**Files:**
- Create: `test/e2e/messaging/direct_message_test.exs`

There is no UI for creating a direct conversation, so we create it programmatically in setup via `Messaging.create_direct_conversation/4`, then test sending/receiving messages through the browser.

- [ ] **Step 1: Write the direct message test file**

```elixir
defmodule KlassHeroWeb.E2E.Messaging.DirectMessageTest do
  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging

  describe "direct messaging" do
    setup %{sandbox_metadata: metadata} do
      # Create provider with password
      provider_user = user_fixture(%{intended_roles: [:provider]})
      provider_user = set_password(provider_user)

      provider =
        insert(:provider_profile_schema,
          identity_id: provider_user.id,
          subscription_tier: "professional"
        )

      # Create parent with password and active tier
      parent_user = user_fixture(%{intended_roles: [:parent]})
      parent_user = set_password(parent_user)

      _parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create a direct conversation between provider and parent
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(
          provider_scope,
          provider.id,
          parent_user.id
        )

      # Send an initial message from provider
      {:ok, _message} =
        Messaging.send_message(conversation.id, provider_user.id, "Hello! Welcome to the program.")

      # Start browser sessions
      provider_session = new_session(metadata)
      parent_session = new_session(metadata)

      provider_session = log_in(provider_session, provider_user)
      parent_session = log_in(parent_session, parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        provider_user: provider_user,
        parent_user: parent_user,
        conversation: conversation
      }
    end

    test "provider sends DM and parent receives it in real-time", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent opens the conversation
      parent_session = visit(parent_session, "/messages/#{conversation.id}")
      assert_message_visible(parent_session, "Hello! Welcome to the program.")

      # Provider navigates to the same conversation
      provider_session = visit(provider_session, "/provider/messages/#{conversation.id}")

      # Provider sends a new message
      provider_session |> send_message("Don't forget your gear tomorrow!")

      # Parent sees the new message without refreshing
      assert_message_visible(parent_session, "Don't forget your gear tomorrow!")
    end

    test "parent replies to DM and provider receives it in real-time", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Both users open the conversation
      provider_session = visit(provider_session, "/provider/messages/#{conversation.id}")
      parent_session = visit(parent_session, "/messages/#{conversation.id}")

      # Parent sends a reply
      parent_session |> send_message("Thanks! What time should we arrive?")

      # Provider sees the reply without refreshing
      assert_message_visible(provider_session, "Thanks! What time should we arrive?")
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test.e2e --max-failures 1`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/messaging/direct_message_test.exs
git commit -m "test: add E2E tests for direct messaging between provider and parent"
```

---

### Task 9: Conversation List E2E Tests (Scenarios 5-6)

**Files:**
- Create: `test/e2e/messaging/conversation_list_test.exs`

- [ ] **Step 1: Write the conversation list test file**

```elixir
defmodule KlassHeroWeb.E2E.Messaging.ConversationListTest do
  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging

  describe "conversation list real-time updates" do
    setup %{sandbox_metadata: metadata} do
      # Create provider with password
      provider_user = user_fixture(%{intended_roles: [:provider]})
      provider_user = set_password(provider_user)

      provider =
        insert(:provider_profile_schema,
          identity_id: provider_user.id,
          subscription_tier: "professional"
        )

      # Create parent with password and active tier
      parent_user = user_fixture(%{intended_roles: [:parent]})
      parent_user = set_password(parent_user)

      _parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create a direct conversation with an initial message from provider
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(provider_scope, provider.id, parent_user.id)

      {:ok, _message} =
        Messaging.send_message(conversation.id, provider_user.id, "Welcome!")

      # Start browser sessions
      provider_session = new_session(metadata)
      parent_session = new_session(metadata)

      provider_session = log_in(provider_session, provider_user)
      parent_session = log_in(parent_session, parent_user)

      %{
        provider_session: provider_session,
        parent_session: parent_session,
        conversation: conversation
      }
    end

    test "conversation list updates in real-time for both parties", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent is on the conversation list
      parent_session = visit_conversations(parent_session, :parent)

      # Provider opens the conversation and sends a new message
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("Schedule change: now at 3pm")

      # Parent's conversation list shows the new message preview
      assert_has(
        parent_session,
        Query.css("[data-role=conversation-card]", text: "Schedule change: now at 3pm")
      )
    end

    test "unread count updates across sessions", %{
      provider_session: provider_session,
      parent_session: parent_session,
      conversation: conversation
    } do
      # Parent is on the conversation list (not inside the conversation)
      parent_session = visit_conversations(parent_session, :parent)

      # Mark existing messages as read first by opening and closing
      parent_session
      |> open_conversation("Welcome!")
      |> visit_conversations(:parent)

      # Provider sends a new message
      provider_session
      |> visit("/provider/messages/#{conversation.id}")
      |> send_message("New message for unread test")

      # Parent should see unread count badge
      assert_unread_count(parent_session, 1)
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test.e2e --max-failures 1`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add test/e2e/messaging/conversation_list_test.exs
git commit -m "test: add E2E tests for conversation list real-time updates and unread counts"
```

---

### Task 10: Mark-as-Read E2E Test (Scenario 7)

**Files:**
- Create: `test/e2e/messaging/mark_as_read_test.exs`

- [ ] **Step 1: Write the mark-as-read test file**

```elixir
defmodule KlassHeroWeb.E2E.Messaging.MarkAsReadTest do
  use KlassHeroWeb.E2ECase

  alias KlassHero.Accounts.Scope
  alias KlassHero.Messaging

  describe "mark as read" do
    setup %{sandbox_metadata: metadata} do
      # Create provider with password
      provider_user = user_fixture(%{intended_roles: [:provider]})
      provider_user = set_password(provider_user)

      provider =
        insert(:provider_profile_schema,
          identity_id: provider_user.id,
          subscription_tier: "professional"
        )

      # Create parent with password and active tier
      parent_user = user_fixture(%{intended_roles: [:parent]})
      parent_user = set_password(parent_user)

      _parent =
        insert(:parent_profile_schema,
          identity_id: parent_user.id,
          subscription_tier: "active"
        )

      # Create conversation with a message from the provider
      # (parent hasn't read it yet = 1 unread)
      provider_scope = Scope.for_user(provider_user) |> Scope.resolve_roles()

      {:ok, conversation} =
        Messaging.create_direct_conversation(provider_scope, provider.id, parent_user.id)

      {:ok, _message} =
        Messaging.send_message(conversation.id, provider_user.id, "Please confirm attendance")

      # Start parent session only (provider doesn't need a browser for this test)
      parent_session = new_session(metadata)
      parent_session = log_in(parent_session, parent_user)

      %{parent_session: parent_session}
    end

    test "opening a conversation marks messages as read", %{
      parent_session: parent_session
    } do
      # Navigate to conversation list
      parent_session = visit_conversations(parent_session, :parent)

      # Should show unread badge
      assert_unread_count(parent_session, 1)

      # Open the conversation (triggers mark_as_read)
      parent_session = open_conversation(parent_session, "Please confirm attendance")

      # Verify message is visible
      assert_message_visible(parent_session, "Please confirm attendance")

      # Navigate back to conversation list
      parent_session = visit_conversations(parent_session, :parent)

      # Unread badge should be gone
      refute_unread_count(parent_session)
    end
  end
end
```

- [ ] **Step 2: Run the tests**

Run: `mix test.e2e --max-failures 1`
Expected: PASS.

- [ ] **Step 3: Run all E2E tests together**

Run: `mix test.e2e`
Expected: All 7 scenarios pass.

- [ ] **Step 4: Commit**

```bash
git add test/e2e/messaging/mark_as_read_test.exs
git commit -m "test: add E2E test for mark-as-read on conversation open"
```

---

### Task 11: CI Workflow

**Files:**
- Modify: `.github/workflows/ci.yml` (add `e2e` job after `test` job)

- [ ] **Step 1: Look up pinned SHA for upload-artifact**

The SHAs to use (verified during design):
- `browser-actions/setup-chrome@v2.1.1` → `3ba2f2bc81ddf8088ecbacdea69d476631049f8b`
- `actions/upload-artifact@v4.6.2` → `ea165f8d65b6e75b540449e92b4886f43607fa02`

Existing pinned SHAs (from the workflow):
- `actions/checkout@v6.0.2` → `de0fac2e4500dabe0009e67214ff5f5447ce83dd`
- `erlef/setup-beam@v1.23.0` → `ee09b1e59bb240681c382eb1f0abc6a04af72764`
- `actions/cache@v5.0.4` → `668228422ae6a00e4ad889ee87cd7109ec5666a7`

- [ ] **Step 2: Add the e2e job**

Append after the `test` job (after line 155) in `.github/workflows/ci.yml`:

```yaml

  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: deps

    services:
      postgres:
        image: postgres:18-alpine
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: klass_hero_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    env:
      MIX_ENV: test

    steps:
      # actions/checkout@v6.0.2
      - name: Checkout code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd

      # erlef/setup-beam@v1.23.0
      - name: Set up Elixir
        uses: erlef/setup-beam@ee09b1e59bb240681c382eb1f0abc6a04af72764
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
          version-type: strict

      # actions/cache@v5.0.4
      - name: Restore dependencies cache
        uses: actions/cache@668228422ae6a00e4ad889ee87cd7109ec5666a7
        with:
          path: |
            deps
            _build
          key: v2-${{ runner.os }}-mix-${{ env.OTP_VERSION }}-${{ env.ELIXIR_VERSION }}-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Set up database
        run: mix ecto.create --quiet && mix ecto.migrate --quiet

      # browser-actions/setup-chrome@v2.1.1
      - name: Install Chrome and ChromeDriver
        uses: browser-actions/setup-chrome@3ba2f2bc81ddf8088ecbacdea69d476631049f8b
        id: setup-chrome
        with:
          chrome-version: stable
          install-chromedriver: true

      - name: Run E2E tests
        env:
          CHROMEDRIVER_PATH: ${{ steps.setup-chrome.outputs.chromedriver-path }}
        run: mix test test/e2e --include e2e

      # actions/upload-artifact@v4.6.2
      - name: Upload E2E screenshots
        if: failure()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
        with:
          name: e2e-screenshots
          path: tmp/e2e_screenshots/
          retention-days: 7
```

- [ ] **Step 3: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "Valid YAML"`
Expected: `Valid YAML`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add E2E test job with Chrome and Wallaby"
```

---

### Task 12: ChromeDriver Setup Script

**Files:**
- Create: `bin/setup-chromedriver`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
#
# Downloads ChromeDriver matching the installed Chrome version.
# Requires: Node.js (npx), Google Chrome installed.
#
# Usage: bin/setup-chromedriver

set -euo pipefail

DEST_DIR="_build/chromedriver"
DEST_BIN="${DEST_DIR}/chromedriver"

# Detect Chrome version
if [[ "$(uname)" == "Darwin" ]]; then
  CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
else
  CHROME_PATH="google-chrome"
fi

if ! command -v "$CHROME_PATH" &>/dev/null && [[ ! -x "$CHROME_PATH" ]]; then
  echo "Error: Google Chrome not found at ${CHROME_PATH}" >&2
  exit 1
fi

CHROME_VERSION=$("$CHROME_PATH" --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
MAJOR=$(echo "$CHROME_VERSION" | cut -d. -f1)

echo "Detected Chrome ${CHROME_VERSION} (major: ${MAJOR})"

# Download matching ChromeDriver via npx
TEMP_DIR=$(mktemp -d)
echo "Downloading ChromeDriver for Chrome ${MAJOR}..."
npx --yes @puppeteer/browsers install "chromedriver@${MAJOR}" --path "${TEMP_DIR}" 2>&1

# Find the downloaded binary
DRIVER_BIN=$(find "${TEMP_DIR}" -name chromedriver -type f | head -1)

if [[ -z "$DRIVER_BIN" ]]; then
  echo "Error: chromedriver binary not found in download" >&2
  rm -rf "${TEMP_DIR}"
  exit 1
fi

# Copy to project destination
mkdir -p "${DEST_DIR}"
cp "${DRIVER_BIN}" "${DEST_BIN}"
chmod +x "${DEST_BIN}"

# Clean up
rm -rf "${TEMP_DIR}"

echo "ChromeDriver installed at ${DEST_BIN}"
"${DEST_BIN}" --version
```

- [ ] **Step 2: Make executable**

Run: `chmod +x bin/setup-chromedriver`

- [ ] **Step 3: Test the script**

Run: `bin/setup-chromedriver`
Expected: Downloads ChromeDriver and prints version.

- [ ] **Step 4: Verify Wallaby can find it**

Run: `mix test.e2e --max-failures 1`
Expected: Tests pass using the locally installed chromedriver.

- [ ] **Step 5: Commit**

```bash
git add bin/setup-chromedriver
git commit -m "chore: add local ChromeDriver setup script"
```

---

### Task 13: Follow-Up Issue and Final Verification

**Files:** None (GitHub issue + verification)

- [ ] **Step 1: Run full precommit check**

Run: `mix precommit`
Expected: All checks pass — compilation, formatting, typography lint, tests.

- [ ] **Step 2: Run all E2E tests**

Run: `mix test.e2e`
Expected: All 7 scenarios pass.

- [ ] **Step 3: Create follow-up issue for scale/concurrency tests**

Run:
```bash
gh issue create \
  --title "[FEATURE] E2E scale/concurrency tests for messaging PubSub fan-out" \
  --body "$(cat <<'EOF'
## Context

Follow-up to #477. The functional E2E test suite is in place with 7 scenarios covering broadcast, direct messaging, conversation list updates, unread counts, and mark-as-read.

This issue covers the scale/concurrency scenarios deferred from the original scope.

## Acceptance Criteria

- [ ] Multiple concurrent parent sessions receiving a broadcast simultaneously
- [ ] Multiple messages sent in rapid succession — all delivered and ordered correctly
- [ ] Multiple providers broadcasting to different programs concurrently
- [ ] Stress test: N parents and M messages to validate PubSub fan-out under load
- [ ] Tests tagged `@tag :e2e_scale` with optional CI inclusion

## Implementation Notes

- Build on the existing `test/e2e/` infrastructure (E2ECase, MessagingHelpers)
- Consider using `Task.async_stream` or Wallaby's multi-session support for concurrent sessions
- May need generous timeouts and CI resource allocation
- Consider making scale tests opt-in in CI initially (`@tag :e2e_scale` excluded by default)
EOF
)" \
  --label "enhancement,testing,backend"
```

- [ ] **Step 4: Commit any final formatting changes**

Run: `mix format`

```bash
git add -A
git commit -m "chore: final formatting for E2E test suite"
```

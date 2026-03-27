# Wallaby E2E Tests for Messaging

**Issue:** #477
**Date:** 2026-03-26
**Status:** Design approved

## Overview

Add browser-driven end-to-end tests for the messaging feature using Wallaby, running in a dedicated CI job that must pass for deployment. This validates the full real-time messaging stack (PubSub, LiveView streams, WebSocket, DOM rendering) as a real user experiences it.

**Scope:** 7 functional scenarios covering provider-to-parent messaging flows. Scale/concurrency tests (50+ sessions, fan-out stress) are deferred to a follow-up issue.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Framework | Wallaby | Elixir-native, Ecto sandbox integration, multi-session support |
| Test scope | Functional only | Scale tests deferred until foundation is stable |
| Directory | `test/e2e/` (separate) | Different sandbox setup needs; clean isolation from `mix test` |
| Architecture | Thin helper layer | Right-sized for 7 scenarios; avoids premature Page Object pattern |
| ChromeDriver (local) | `bin/setup-chromedriver` via `npx @puppeteer/browsers` | Homebrew cask deprecated (Gatekeeper); npx avoids quarantine |
| ChromeDriver (CI) | `browser-actions/setup-chrome` with `install-chromedriver` | Single action, guaranteed version match |
| Auth in tests | Login through UI | Realistic; reusable `log_in/3` helper wraps the flow |
| CI gating | E2E must pass for deploy | `fly-deploy.yml` triggers on CI success; adding job auto-gates |
| Action pinning | Commit SHA with version comment | Consistent with existing CI workflow |
| Template anchors | `data-role` attributes | Stable selectors decoupled from CSS classes |

## Dependencies

### New hex dependency

```elixir
{:wallaby, "~> 0.30", only: :test, runtime: false}
```

### ChromeDriver

**Local dev (macOS):**

`bin/setup-chromedriver` shell script that:
1. Detects installed Chrome major version via `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --version`
2. Downloads matching ChromeDriver via `npx @puppeteer/browsers install chromedriver@{major}`
3. Copies binary to `_build/chromedriver/chromedriver`

**CI:**

```yaml
# browser-actions/setup-chrome@v2.1.1
- uses: browser-actions/setup-chrome@3ba2f2bc81ddf8088ecbacdea69d476631049f8b
  id: setup-chrome
  with:
    chrome-version: stable
    install-chromedriver: true
```

## Configuration

### `config/test.exs` additions

```elixir
config :wallaby,
  driver: Wallaby.Chrome,
  screenshot_on_failure: true,
  screenshot_dir: "tmp/e2e_screenshots",
  chrome: [headless: true],
  chromedriver: [path: System.get_env("CHROMEDRIVER_PATH", "_build/chromedriver/chromedriver")]

config :klass_hero, sql_sandbox: true
```

Change `server: false` to `server: true` in the existing endpoint config in `config/test.exs`. The HTTP server on port 4002 is harmless for regular tests — `Phoenix.LiveViewTest` communicates directly with LiveView processes regardless of whether the server is running. Wallaby needs it to connect via HTTP.

### Endpoint sandbox plug

In `lib/klass_hero_web/endpoint.ex`, add conditionally:

```elixir
if Application.compile_env(:klass_hero, :sql_sandbox) do
  plug Phoenix.Ecto.SQL.Sandbox
end
```

Placed before the router plug. Only active in test env via the config flag.

### ExUnit tag exclusion

In `test/test_helper.exs`:

```elixir
ExUnit.start(exclude: [:integration, :e2e], capture_log: true)
```

### Compile paths

In `mix.exs`:

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support", "test/e2e/support"]
```

### Mix alias

```elixir
"test.e2e": ["test test/e2e --include e2e"]
```

## Directory Structure

```
test/e2e/
├── support/
│   ├── e2e_case.ex              # ExUnit.CaseTemplate with sandbox + session setup
│   └── messaging_helpers.ex     # Thin helper layer (login, send, assert)
└── messaging/
    ├── broadcast_test.exs       # Scenarios 1-2: broadcast + private reply
    ├── direct_message_test.exs  # Scenarios 3-4: DM send + reply
    ├── conversation_list_test.exs # Scenarios 5-6: list updates + unread count
    └── mark_as_read_test.exs    # Scenario 7: mark-as-read on open
```

No separate `test/e2e/test_helper.exs` — `mix test` always uses the root `test/test_helper.exs`. Wallaby is started lazily in `E2ECase.setup_all`.

## Support Modules

### `E2ECase`

ExUnit.CaseTemplate that:
- Starts Wallaby once per test module via `setup_all` (lazy — only runs when E2E tests execute)
- Injects `use Wallaby.DSL`, factory imports, helper imports
- Tags all tests with `@moduletag :e2e`
- Sets up Ecto sandbox ownership and generates metadata for the sandbox plug
- Cleans up sandbox on exit

Since `:e2e` is excluded by default in `test/test_helper.exs`, `setup_all` never runs during regular `mix test`, so chromedriver is not required for normal test runs.

```elixir
defmodule KlassHeroWeb.E2ECase do
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

  setup_all do
    {:ok, _} = Application.ensure_all_started(:wallaby)
    :ok
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(KlassHero.Repo, shared: not tags[:async])
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(KlassHero.Repo, pid)

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, sandbox_metadata: metadata}
  end
end
```

### `MessagingHelpers`

Thin helper module centralizing DOM selectors and common multi-step interactions:

| Helper | Purpose |
|--------|---------|
| `new_session(metadata)` | Start Wallaby session with sandbox metadata |
| `log_in(session, email, password)` | Navigate to login page, fill form, submit |
| `send_message(session, text)` | Fill message input, click send |
| `assert_message_visible(session, text)` | Assert message with text exists in DOM |
| `assert_unread_count(session, count)` | Assert unread badge shows expected number |
| `visit_conversations(session, role)` | Navigate to conversation list (role-aware path) |
| `open_conversation(session, name)` | Click conversation card by name |

Selectors use `data-role` attributes for stability (e.g., `[data-role=message]`, `[data-role=unread-count]`).

## Test Scenarios

All tests use multi-session Wallaby: one browser session per user role, both sharing the same Ecto sandbox transaction.

### Setup pattern

Each test file's `setup` block:
1. Creates users with known passwords via fixtures
2. Creates role profiles (provider, parent) via factories
3. Creates program + enrollment linking them
4. Starts Wallaby sessions with sandbox metadata
5. Logs in both users through the UI

### Scenario 1: Provider broadcasts → parent sees it in real-time

- **File:** `broadcast_test.exs`
- **Provider session:** Navigate to broadcast page, select program, type message, submit
- **Parent session:** On conversation list, assert broadcast message appears without refresh

### Scenario 2: Parent replies privately to broadcast → provider sees private conversation

- **File:** `broadcast_test.exs`
- **Setup:** Broadcast already sent
- **Parent session:** Open broadcast, click "Reply Privately", type reply, submit
- **Provider session:** Assert new private conversation appears in list

### Scenario 3: Provider sends DM → parent receives in real-time

- **File:** `direct_message_test.exs`
- **Provider session:** Create direct conversation with parent, type message, send
- **Parent session:** Assert conversation appears, open it, verify message content

### Scenario 4: Parent replies to DM → provider receives in real-time

- **File:** `direct_message_test.exs`
- **Setup:** Existing DM conversation with one message
- **Parent session:** Open conversation, type reply, send
- **Provider session:** Assert reply appears in same conversation without refresh

### Scenario 5: Conversation list updates in real-time

- **File:** `conversation_list_test.exs`
- **Setup:** Existing conversation between provider and parent
- **Provider session:** Send a new message
- **Parent session:** On conversation list, assert conversation shows latest message preview

### Scenario 6: Unread count updates across sessions

- **File:** `conversation_list_test.exs`
- **Setup:** Parent on conversation list (not inside a conversation)
- **Provider session:** Send a message
- **Parent session:** Assert unread count badge increments

### Scenario 7: Opening conversation marks messages as read

- **File:** `mark_as_read_test.exs`
- **Setup:** Provider sent a message, parent has 1 unread
- **Parent session:** Verify unread badge shows "1", open conversation, navigate back, verify badge gone

## Template Changes

Add `data-role` attributes to existing messaging component elements:

| Attribute | Element | Location |
|-----------|---------|----------|
| `data-role="message"` | Message bubble | `messaging_components.ex` |
| `data-role="conversation-card"` | Conversation list item | `messaging_components.ex` |
| `data-role="unread-count"` | Unread badge | `messaging_components.ex` |
| `data-role="message-input"` | Message textarea | Show LiveViews |
| `data-role="send-message-btn"` | Send button | Show LiveViews |

Existing `id` attributes are reused where they already exist (e.g., `#message-input`). Only missing anchors are added.

## CI Integration

### New `e2e` job in `.github/workflows/ci.yml`

Runs parallel to `quality` and `test`, depends on `deps`.

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

### Deploy gating

No changes to `fly-deploy.yml`. It triggers on CI workflow success (`conclusion == 'success'`), which requires all jobs to pass. Adding the `e2e` job automatically makes it a deploy gate.

## Local Developer Experience

### Setup

1. Run `bin/setup-chromedriver` (one-time, or after Chrome updates)
2. Run `mix test.e2e` to execute E2E tests

### Commands

| Command | What it does |
|---------|-------------|
| `mix test` | Unit/integration tests only (E2E excluded) |
| `mix test.e2e` | E2E tests only |
| `mix precommit` | Unchanged (does not run E2E) |

## Follow-up Issue

After the functional E2E suite is stable, file a separate issue for scale/concurrency tests:

- Multiple concurrent parent sessions receiving broadcasts simultaneously
- Rapid-fire messages: all delivered and ordered correctly
- Multiple providers broadcasting to different programs concurrently
- Stress test: N parents, M messages to validate PubSub fan-out under load

## Files Changed Summary

| File | Change |
|------|--------|
| `mix.exs` | Add `wallaby` dep, update `elixirc_paths`, add `test.e2e` alias |
| `config/test.exs` | Add Wallaby config, `sql_sandbox: true` |
| `lib/klass_hero_web/endpoint.ex` | Add conditional `Phoenix.Ecto.SQL.Sandbox` plug |
| `test/test_helper.exs` | Add `:e2e` to exclusion list |
| `test/e2e/support/e2e_case.ex` | New — ExUnit.CaseTemplate (starts Wallaby lazily) |
| `test/e2e/support/messaging_helpers.ex` | New — thin helper layer |
| `test/e2e/messaging/broadcast_test.exs` | New — scenarios 1-2 |
| `test/e2e/messaging/direct_message_test.exs` | New — scenarios 3-4 |
| `test/e2e/messaging/conversation_list_test.exs` | New — scenarios 5-6 |
| `test/e2e/messaging/mark_as_read_test.exs` | New — scenario 7 |
| `lib/klass_hero_web/components/messaging_components.ex` | Add `data-role` attributes |
| `lib/klass_hero_web/live/messages_live/show.ex` | Add `data-role` to input/button if missing |
| `lib/klass_hero_web/live/provider/messages_live/show.ex` | Add `data-role` to input/button if missing |
| `.github/workflows/ci.yml` | Add `e2e` job |
| `bin/setup-chromedriver` | New — local ChromeDriver installer script |
| `.gitignore` | Add `_build/chromedriver/`, `tmp/e2e_screenshots/` |

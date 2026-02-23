# Invite Email Sending Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> **REQUIRED DISCIPLINE:** Use superpowers:test-driven-development for all tasks. NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.

**Goal:** Send invitation emails to guardians after CSV bulk enrollment import, transitioning invites from `pending` to `invite_sent`.

**Architecture:** Domain event from import use case → event handler generates tokens + enqueues Oban jobs → one worker per invite builds HTML+text email via port/adapter → delivers via Swoosh/Resend → transitions invite status.

**Tech Stack:** Elixir/Phoenix, Swoosh (Resend adapter), Oban (background jobs), Req (HTTP client)

**Design doc:** `docs/plans/2026-02-23-invite-email-sending-design.md`

**TDD exceptions (config only):** Tasks 1 and 9 are pure configuration — no tests needed per TDD skill rules.

---

### Task 1: Configuration Foundation (no TDD — config files)

**Files:**
- Modify: `config/config.exs`
- Modify: `config/runtime.exs`

**Steps:**

1. In `config/config.exs`, after `config :klass_hero, KlassHero.Mailer`, add:
   ```elixir
   config :klass_hero, :mailer_defaults,
     from: {"KlassHero", "noreply@mail.klasshero.com"}
   ```

2. In `config/config.exs`, change Oban `queues:` to:
   ```elixir
   queues: [default: 10, messaging: 5, cleanup: 2, email: 5]
   ```

3. In `config/config.exs`, add to `:enrollment` config block:
   ```elixir
   for_sending_invite_emails:
     KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifier
   ```

4. In `config/runtime.exs`, replace commented mailer section (lines 127-143) with:
   ```elixir
   config :klass_hero, KlassHero.Mailer,
     adapter: Swoosh.Adapters.Resend,
     api_key: System.get_env("RESEND_API_KEY") || raise("RESEND_API_KEY not set")
   ```

5. Commit:
   ```bash
   git commit -m "config: add Resend mailer, email queue, and mailer defaults (#176)"
   ```

---

### Task 2: Update UserNotifier to Use Shared Config (refactor — existing tests cover)

**Files:**
- Modify: `lib/klass_hero/accounts/user_notifier.ex:16`

**Steps:**

1. Run existing tests to confirm baseline:
   ```bash
   mix test test/klass_hero/accounts/ --max-failures 3
   ```

2. In `user_notifier.ex`, change `from` in `deliver/3` from:
   ```elixir
   |> from({"KlassHero", "contact@example.com"})
   ```
   to:
   ```elixir
   |> from(Application.compile_env!(:klass_hero, [:mailer_defaults, :from]))
   ```

3. Verify existing tests still pass:
   ```bash
   mix test test/klass_hero/accounts/ --max-failures 3
   ```

4. Commit:
   ```bash
   git commit -m "refactor: use shared mailer_defaults config in UserNotifier (#176)"
   ```

---

### Task 3: Repository — `get_by_id/1`

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Modify: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

#### RED: Write failing test

Add to repository test file:

```elixir
describe "get_by_id/1" do
  setup :setup_program

  test "returns invite when found", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)

    result = BulkEnrollmentInviteRepository.get_by_id(invite.id)
    assert result.id == invite.id
    assert result.guardian_email == "parent@example.com"
  end

  test "returns nil when not found" do
    assert BulkEnrollmentInviteRepository.get_by_id(Ecto.UUID.generate()) == nil
  end
end
```

#### Verify RED

```bash
mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs --max-failures 1
```
Expected: FAIL — `get_by_id/1` undefined

#### GREEN: Minimal implementation

Add port callback to `for_storing_bulk_enrollment_invites.ex`:
```elixir
@callback get_by_id(binary()) :: struct() | nil
```

Add to repository:
```elixir
@impl true
def get_by_id(id) when is_binary(id) do
  Repo.get(BulkEnrollmentInviteSchema, id)
end
```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs
```
Expected: all PASS

#### Commit

```bash
git commit -m "feat: add get_by_id/1 to invite repository (#176)"
```

---

### Task 4: Repository — `list_pending_without_token/1`

Same files as Task 3.

#### RED

```elixir
describe "list_pending_without_token/1" do
  setup :setup_program

  test "returns pending invites with no token", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])

    result = BulkEnrollmentInviteRepository.list_pending_without_token([program.id])
    assert length(result) == 1
    assert hd(result).status == "pending"
    assert hd(result).invite_token == nil
  end

  test "excludes invites that already have tokens", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)
    invite |> Ecto.Changeset.change(%{invite_token: "existing-token"}) |> Repo.update!()

    assert BulkEnrollmentInviteRepository.list_pending_without_token([program.id]) == []
  end

  test "excludes non-pending invites", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)

    invite
    |> BulkEnrollmentInviteSchema.transition_changeset(%{status: "failed", error_details: "test"})
    |> Repo.update!()

    assert BulkEnrollmentInviteRepository.list_pending_without_token([program.id]) == []
  end

  test "returns empty list for empty program_ids" do
    assert BulkEnrollmentInviteRepository.list_pending_without_token([]) == []
  end
end
```

#### Verify RED

```bash
mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs --max-failures 1
```
Expected: FAIL — function undefined

#### GREEN

Port callback:
```elixir
@callback list_pending_without_token([binary()]) :: [struct()]
```

Repository:
```elixir
@impl true
def list_pending_without_token([]), do: []

def list_pending_without_token(program_ids) when is_list(program_ids) do
  BulkEnrollmentInviteSchema
  |> where([i], i.program_id in ^program_ids)
  |> where([i], i.status == "pending")
  |> where([i], is_nil(i.invite_token))
  |> Repo.all()
end
```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs
```

#### Commit

```bash
git commit -m "feat: add list_pending_without_token/1 to invite repository (#176)"
```

---

### Task 5: Repository — `bulk_assign_tokens/1`

#### RED

```elixir
describe "bulk_assign_tokens/1" do
  setup :setup_program

  test "assigns tokens to invites", %{program: program, provider: provider} do
    rows = [
      valid_invite_attrs(program, provider),
      valid_invite_attrs(program, provider, %{child_first_name: "Liam", guardian_email: "b@test.com"})
    ]

    {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)
    invites = Repo.all(BulkEnrollmentInviteSchema)
    pairs = Enum.map(invites, fn inv -> {inv.id, "token-#{inv.id}"} end)

    assert {:ok, 2} = BulkEnrollmentInviteRepository.bulk_assign_tokens(pairs)

    updated = Repo.all(BulkEnrollmentInviteSchema)
    assert Enum.all?(updated, fn inv -> inv.invite_token != nil end)
  end

  test "returns {:ok, 0} for empty list" do
    assert {:ok, 0} = BulkEnrollmentInviteRepository.bulk_assign_tokens([])
  end
end
```

#### Verify RED → FAIL

#### GREEN

Port callback:
```elixir
@callback bulk_assign_tokens([{binary(), String.t()}]) :: {:ok, non_neg_integer()}
```

Repository:
```elixir
@impl true
def bulk_assign_tokens([]), do: {:ok, 0}

def bulk_assign_tokens(id_token_pairs) when is_list(id_token_pairs) do
  now = DateTime.utc_now() |> DateTime.truncate(:second)

  {count, _} =
    Enum.reduce(id_token_pairs, {0, nil}, fn {id, token}, {count, _} ->
      {rows_updated, _} =
        BulkEnrollmentInviteSchema
        |> where([i], i.id == ^id)
        |> Repo.update_all(set: [invite_token: token, updated_at: now])

      {count + rows_updated, nil}
    end)

  {:ok, count}
end
```

#### Verify GREEN → PASS

#### Commit

```bash
git commit -m "feat: add bulk_assign_tokens/1 to invite repository (#176)"
```

---

### Task 6: Repository — `transition_status/2`

#### RED

```elixir
describe "transition_status/2" do
  setup :setup_program

  test "transitions pending to invite_sent", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)

    assert {:ok, updated} =
             BulkEnrollmentInviteRepository.transition_status(invite, %{
               status: "invite_sent",
               invite_token: "test-token",
               invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
             })

    assert updated.status == "invite_sent"
    assert updated.invite_token == "test-token"
    assert updated.invite_sent_at != nil
  end

  test "transitions pending to failed", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)

    assert {:ok, updated} =
             BulkEnrollmentInviteRepository.transition_status(invite, %{
               status: "failed",
               error_details: "delivery failed"
             })

    assert updated.status == "failed"
    assert updated.error_details == "delivery failed"
  end

  test "rejects invalid transition", %{program: program, provider: provider} do
    {:ok, 1} = BulkEnrollmentInviteRepository.create_batch([valid_invite_attrs(program, provider)])
    invite = Repo.one!(BulkEnrollmentInviteSchema)

    assert {:error, %Ecto.Changeset{}} =
             BulkEnrollmentInviteRepository.transition_status(invite, %{status: "enrolled"})
  end
end
```

#### Verify RED → FAIL

#### GREEN

Port callback:
```elixir
@callback transition_status(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
```

Repository:
```elixir
@impl true
def transition_status(%BulkEnrollmentInviteSchema{} = invite, attrs) when is_map(attrs) do
  invite
  |> BulkEnrollmentInviteSchema.transition_changeset(attrs)
  |> Repo.update()
end
```

#### Verify GREEN → PASS

#### Commit

```bash
git commit -m "feat: add transition_status/2 to invite repository (#176)"
```

---

### Task 7: Email Port + InviteEmailNotifier

**Files:**
- Create: `lib/klass_hero/enrollment/domain/ports/for_sending_invite_emails.ex`
- Create: `lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier_test.exs`

#### RED: Write all tests first

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifierTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifier

  defp build_invite(overrides \\ %{}) do
    Map.merge(
      %{
        guardian_email: "parent@example.com",
        guardian_first_name: "Hans",
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        invite_token: "test-token-abc"
      },
      overrides
    )
  end

  @url "https://app.klasshero.com/invites/test-token-abc"

  describe "send_invite/3" do
    test "delivers email with correct recipient and subject" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.to == [{"Hans", "parent@example.com"}]
      assert email.subject =~ "Emma"
      assert email.subject =~ "Dance Class"
    end

    test "uses mailer_defaults sender" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.from == {"KlassHero", "noreply@mail.klasshero.com"}
    end

    test "includes invite URL in text body" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.text_body =~ @url
      assert email.text_body =~ "Emma"
      assert email.text_body =~ "Dance Class"
    end

    test "includes invite URL and child name in HTML body" do
      {:ok, email} = InviteEmailNotifier.send_invite(build_invite(), "Dance Class", @url)

      assert email.html_body =~ @url
      assert email.html_body =~ "Emma"
      assert email.html_body =~ "Dance Class"
    end

    test "falls back to email as recipient name when guardian_first_name is nil" do
      invite = build_invite(%{guardian_first_name: nil})
      {:ok, email} = InviteEmailNotifier.send_invite(invite, "Dance Class", @url)

      assert email.to == [{"parent@example.com", "parent@example.com"}]
    end
  end
end
```

#### Verify RED

```bash
mix test test/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier_test.exs --max-failures 1
```
Expected: FAIL — module not found

#### GREEN: Create port + adapter

Port (`lib/klass_hero/enrollment/domain/ports/for_sending_invite_emails.ex`):

```elixir
defmodule KlassHero.Enrollment.Domain.Ports.ForSendingInviteEmails do
  @moduledoc """
  Port for sending enrollment invitation emails.
  """

  @callback send_invite(invite :: struct() | map(), program_name :: String.t(), invite_url :: String.t()) ::
              {:ok, term()} | {:error, term()}
end
```

Adapter (`lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex`):

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Notifications.InviteEmailNotifier do
  @moduledoc """
  Swoosh adapter for sending enrollment invitation emails.

  Composes HTML + plain text emails and delivers via KlassHero.Mailer.
  """

  @behaviour KlassHero.Enrollment.Domain.Ports.ForSendingInviteEmails

  import Swoosh.Email

  alias KlassHero.Mailer

  @from Application.compile_env!(:klass_hero, [:mailer_defaults, :from])

  @impl true
  def send_invite(invite, program_name, invite_url) do
    recipient_name = invite.guardian_first_name || invite.guardian_email

    email =
      new()
      |> to({recipient_name, invite.guardian_email})
      |> from(@from)
      |> subject("You're invited to enroll #{invite.child_first_name} in #{program_name}")
      |> text_body(text_body(invite, program_name, invite_url))
      |> html_body(html_body(invite, program_name, invite_url))

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp text_body(invite, program_name, invite_url) do
    greeting = invite.guardian_first_name || "there"

    """
    Hi #{greeting},

    You've been invited to enroll #{invite.child_first_name} #{invite.child_last_name} in #{program_name}.

    Complete your registration here:
    #{invite_url}

    If you didn't expect this email, you can safely ignore it.

    - The KlassHero Team
    """
  end

  defp html_body(invite, program_name, invite_url) do
    greeting = invite.guardian_first_name || "there"

    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #333;">
      <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #4F46E5;">
        <h1 style="color: #4F46E5; margin: 0; font-size: 24px;">KlassHero</h1>
      </div>
      <div style="padding: 30px 0;">
        <p>Hi #{greeting},</p>
        <p>You've been invited to enroll <strong>#{invite.child_first_name} #{invite.child_last_name}</strong> in <strong>#{program_name}</strong>.</p>
        <div style="text-align: center; padding: 20px 0;">
          <a href="#{invite_url}" style="background-color: #4F46E5; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: 600; display: inline-block;">Complete Registration</a>
        </div>
        <p style="color: #666; font-size: 14px;">Or copy this link: #{invite_url}</p>
      </div>
      <div style="border-top: 1px solid #eee; padding-top: 15px; color: #999; font-size: 12px;">
        <p>If you didn't expect this email, you can safely ignore it.</p>
      </div>
    </body>
    </html>
    """
  end
end
```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier_test.exs
```

Note: `Swoosh.Adapters.Test` with `config :swoosh, :api_client, false` returns `{:ok, %{}}` from `Mailer.deliver/1`. Adjust test assertions if the return shape differs — key thing is `send_invite/3` returns `{:ok, email}`.

#### Commit

```bash
git commit -m "feat: add invite email port and notifier adapter (#176)"
```

---

### Task 8: Enrollment Events Factory — `bulk_invites_imported`

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/events/enrollment_events.ex`
- Create: `test/klass_hero/enrollment/domain/events/enrollment_events_test.exs` (if doesn't exist)

#### RED

```elixir
defmodule KlassHero.Enrollment.Domain.Events.EnrollmentEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.Domain.Events.DomainEvent

  describe "bulk_invites_imported/4" do
    test "creates event with correct type and payload" do
      event = EnrollmentEvents.bulk_invites_imported("provider-1", ["prog-1", "prog-2"], 5)

      assert %DomainEvent{} = event
      assert event.event_type == :bulk_invites_imported
      assert event.aggregate_type == :enrollment
      assert event.aggregate_id == "provider-1"
      assert event.payload.provider_id == "provider-1"
      assert event.payload.program_ids == ["prog-1", "prog-2"]
      assert event.payload.count == 5
    end
  end
end
```

#### Verify RED → FAIL (function undefined)

#### GREEN

Add to `enrollment_events.ex`:

```elixir
def bulk_invites_imported(provider_id, program_ids, count, opts \\ [])

def bulk_invites_imported(provider_id, program_ids, count, opts)
    when is_binary(provider_id) and is_list(program_ids) and is_integer(count) do
  DomainEvent.new(
    :bulk_invites_imported,
    provider_id,
    @aggregate_type,
    %{provider_id: provider_id, program_ids: program_ids, count: count},
    opts
  )
end
```

Update `@moduledoc` to list the new event.

#### Verify GREEN → PASS

#### Commit

```bash
git commit -m "feat: add bulk_invites_imported event factory (#176)"
```

---

### Task 9: Wire Event Handler in Application (no TDD — config wiring)

**Files:**
- Modify: `lib/klass_hero/application.ex`

**Steps:**

1. In `application.ex`, find the Enrollment DomainEventBus child spec (~line 99). Add to the `handlers:` list:

   ```elixir
   {:bulk_invites_imported,
    {KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails,
     :handle}}
   ```

2. Verify compilation: `mix compile --warnings-as-errors`
   Note: `EnqueueInviteEmails` module doesn't exist yet — this will warn. If so, skip this step and do it after Task 11 instead.

3. Commit (or defer to after Task 11):
   ```bash
   git commit -m "feat: register invite email handler on enrollment event bus (#176)"
   ```

---

### Task 10: Oban Worker — `SendInviteEmailWorker`

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker_test.exs`

#### RED

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorkerTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker
  alias KlassHero.Repo

  defp create_pending_invite(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Dance Class")

    {:ok, 1} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Emma",
          child_last_name: "Schmidt",
          child_date_of_birth: ~D[2016-03-15],
          guardian_email: "parent@example.com",
          guardian_first_name: "Hans"
        }
      ])

    invite = Repo.one!(BulkEnrollmentInviteSchema)
    invite = invite |> Ecto.Changeset.change(%{invite_token: "test-token-123"}) |> Repo.update!()

    %{invite: invite, program: program}
  end

  describe "perform/1" do
    setup :create_pending_invite

    test "sends email and transitions to invite_sent", %{invite: invite, program: program} do
      assert {:ok, _} =
               SendInviteEmailWorker.perform(%Oban.Job{
                 args: %{"invite_id" => invite.id, "program_name" => program.title}
               })

      updated = Repo.get!(BulkEnrollmentInviteSchema, invite.id)
      assert updated.status == "invite_sent"
      assert updated.invite_sent_at != nil
    end

    test "skips already-sent invite", %{invite: invite, program: program} do
      invite
      |> BulkEnrollmentInviteSchema.transition_changeset(%{
        status: "invite_sent",
        invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update!()

      assert {:ok, :skipped} =
               SendInviteEmailWorker.perform(%Oban.Job{
                 args: %{"invite_id" => invite.id, "program_name" => program.title}
               })
    end

    test "returns :not_found for missing invite" do
      assert {:ok, :not_found} =
               SendInviteEmailWorker.perform(%Oban.Job{
                 args: %{"invite_id" => Ecto.UUID.generate(), "program_name" => "Dance"}
               })
    end

    test "returns error when invite has no token", %{invite: invite, program: program} do
      invite |> Ecto.Changeset.change(%{invite_token: nil}) |> Repo.update!()

      assert {:error, "invite has no token"} =
               SendInviteEmailWorker.perform(%Oban.Job{
                 args: %{"invite_id" => invite.id, "program_name" => program.title}
               })
    end
  end
end
```

#### Verify RED → FAIL (module not defined)

#### GREEN

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker do
  @moduledoc """
  Oban worker that sends a single enrollment invitation email.

  Fetches the invite, builds the email via the configured notifier adapter,
  and transitions the invite status from `pending` to `invite_sent`.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @invite_notifier Application.compile_env!(:klass_hero, [
                     :enrollment,
                     :for_sending_invite_emails
                   ])

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invite_id" => invite_id, "program_name" => program_name}}) do
    case @invite_repository.get_by_id(invite_id) do
      nil ->
        Logger.warning("[SendInviteEmailWorker] Invite not found", invite_id: invite_id)
        {:ok, :not_found}

      # Trigger: invite already processed (not pending)
      # Why: Oban may retry, or event re-dispatched — skip to avoid duplicate emails
      # Outcome: return :skipped without sending
      %{status: status} when status != "pending" ->
        Logger.info("[SendInviteEmailWorker] Skipping non-pending invite",
          invite_id: invite_id,
          status: status
        )
        {:ok, :skipped}

      %{invite_token: nil} ->
        Logger.warning("[SendInviteEmailWorker] Invite has no token", invite_id: invite_id)
        {:error, "invite has no token"}

      invite ->
        send_and_transition(invite, program_name)
    end
  end

  defp send_and_transition(invite, program_name) do
    invite_url = "#{KlassHeroWeb.Endpoint.url()}/invites/#{invite.invite_token}"

    case @invite_notifier.send_invite(invite, program_name, invite_url) do
      {:ok, _email} ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        @invite_repository.transition_status(invite, %{
          status: "invite_sent",
          invite_sent_at: now
        })

      {:error, reason} ->
        Logger.error("[SendInviteEmailWorker] Email delivery failed",
          invite_id: invite.id,
          reason: inspect(reason)
        )

        @invite_repository.transition_status(invite, %{
          status: "failed",
          error_details: "Email delivery failed: #{inspect(reason)}"
        })

        {:error, reason}
    end
  end
end
```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker_test.exs
```

#### Commit

```bash
git commit -m "feat: add Oban worker for sending invite emails (#176)"
```

---

### Task 11: Event Handler — `EnqueueInviteEmails`

**Files:**
- Create: `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails.ex`
- Create: `test/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails_test.exs`

#### RED

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmailsTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.BulkEnrollmentInviteSchema
  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Repo

  defp create_pending_invites(_context) do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id, title: "Dance Class")

    rows = [
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Emma",
        child_last_name: "Schmidt",
        child_date_of_birth: ~D[2016-03-15],
        guardian_email: "parent@example.com",
        guardian_first_name: "Hans"
      },
      %{
        program_id: program.id,
        provider_id: provider.id,
        child_first_name: "Liam",
        child_last_name: "Mueller",
        child_date_of_birth: ~D[2017-01-10],
        guardian_email: "other@example.com",
        guardian_first_name: "Maria"
      }
    ]

    {:ok, 2} = BulkEnrollmentInviteRepository.create_batch(rows)
    %{provider: provider, program: program}
  end

  describe "handle/1" do
    setup :create_pending_invites

    test "assigns tokens to all pending invites", %{provider: provider, program: program} do
      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
      assert :ok = EnqueueInviteEmails.handle(event)

      invites = Repo.all(BulkEnrollmentInviteSchema)
      assert Enum.all?(invites, fn inv -> inv.invite_token != nil end)
      assert length(Enum.uniq_by(invites, & &1.invite_token)) == 2
    end

    test "does nothing when no pending invites exist", %{provider: provider, program: program} do
      Repo.update_all(BulkEnrollmentInviteSchema, set: [status: "failed", error_details: "test"])

      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 0)
      assert :ok = EnqueueInviteEmails.handle(event)
    end

    test "skips invites that already have tokens", %{provider: provider, program: program} do
      invite = Repo.all(BulkEnrollmentInviteSchema) |> hd()
      invite |> Ecto.Changeset.change(%{invite_token: "pre-existing"}) |> Repo.update!()

      event = EnrollmentEvents.bulk_invites_imported(provider.id, [program.id], 2)
      assert :ok = EnqueueInviteEmails.handle(event)

      invites = Repo.all(BulkEnrollmentInviteSchema)
      assert Enum.find(invites, &(&1.invite_token == "pre-existing")) != nil
    end
  end
end
```

#### Verify RED → FAIL

#### GREEN

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Events.EventHandlers.EnqueueInviteEmails do
  @moduledoc """
  Domain event handler that generates invite tokens and enqueues
  Oban jobs to send invitation emails.

  Triggered by `:bulk_invites_imported` on the Enrollment DomainEventBus.

  ## Idempotency

  Queries only invites with `status = "pending" AND invite_token IS NULL`.
  Re-dispatching the event won't duplicate email sends.
  """

  alias KlassHero.Enrollment.Adapters.Driven.Workers.SendInviteEmailWorker
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])
  @program_catalog_acl Application.compile_env!(:klass_hero, [
                         :enrollment,
                         :for_resolving_program_catalog
                       ])

  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :bulk_invites_imported} = event) do
    %{provider_id: provider_id, program_ids: program_ids, count: count} = event.payload

    Logger.info("[EnqueueInviteEmails] Processing bulk import event",
      provider_id: provider_id,
      program_count: length(program_ids),
      invite_count: count
    )

    pending_invites = @invite_repository.list_pending_without_token(program_ids)

    if pending_invites == [] do
      Logger.info("[EnqueueInviteEmails] No pending invites to process")
      :ok
    else
      process_invites(pending_invites, provider_id)
    end
  end

  defp process_invites(invites, provider_id) do
    # Trigger: program_id → program_name lookup needed for email subjects
    # Why: invite schema stores program_id but email needs human-readable name
    # Outcome: reverse the title→id ACL map to get id→title
    programs_by_id = build_programs_by_id(provider_id)

    id_token_pairs = Enum.map(invites, fn invite -> {invite.id, generate_token()} end)
    {:ok, _count} = @invite_repository.bulk_assign_tokens(id_token_pairs)

    jobs =
      Enum.map(invites, fn invite ->
        program_name = Map.get(programs_by_id, invite.program_id, "Program")

        SendInviteEmailWorker.new(%{
          invite_id: invite.id,
          program_name: program_name
        })
      end)

    Oban.insert_all(jobs)

    Logger.info("[EnqueueInviteEmails] Enqueued invite emails", count: length(jobs))
    :ok
  end

  defp build_programs_by_id(provider_id) do
    @program_catalog_acl.list_program_titles_for_provider(provider_id)
    |> Map.new(fn {title, id} -> {id, title} end)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails_test.exs
```

Note: Oban `:inline` mode in tests means `Oban.insert_all/1` executes the workers immediately. Since the handler assigns tokens then enqueues, and the worker reads the token — this should work end-to-end in tests. If timing is an issue, the tests focus on token assignment which happens synchronously before Oban.

#### Commit

```bash
git commit -m "feat: add event handler to enqueue invite emails after import (#176)"
```

If Task 9 was deferred, do it now and commit the `application.ex` wiring.

---

### Task 12: Publish Domain Event from Import Use Case

**Files:**
- Modify: `lib/klass_hero/enrollment/application/use_cases/import_enrollment_csv.ex`
- Read: `test/klass_hero/enrollment/application/use_cases/import_enrollment_csv_test.exs`

#### RED: Add test for event dispatch

Read the existing import use case test file first to understand its structure. Then add a test that verifies the event is dispatched on successful import. Pattern depends on how existing tests handle events — likely the `TestEventPublisher` is configured in test env.

If the DomainEventBus is running in test (it is — started in supervision tree), the simplest approach is to verify side effects: after a successful import, pending invites should have tokens assigned (because the handler runs synchronously via the bus).

```elixir
# Add to the existing import use case test, in the success test describe block:
test "assigns invite tokens after successful import", %{...} do
  # (use existing test setup that does a successful import)
  assert {:ok, %{created: _}} = ImportEnrollmentCsv.execute(provider_id, csv_binary)

  # Verify the handler ran: invites should have tokens
  invites = Repo.all(BulkEnrollmentInviteSchema)
  assert Enum.all?(invites, fn inv -> inv.invite_token != nil end)
end
```

#### Verify RED → FAIL (tokens not assigned because event not published yet)

#### GREEN

In `import_enrollment_csv.ex`:

1. Add aliases:
   ```elixir
   alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
   alias KlassHero.Shared.EventDispatchHelper
   ```

2. Change the success path in `execute/2`:
   ```elixir
   {:ok, count} <- persist_batch(validated_rows) do
     program_ids = validated_rows |> Enum.map(& &1.program_id) |> Enum.uniq()
     publish_event(provider_id, program_ids, count)
     {:ok, %{created: count}}
   end
   ```

3. Add private function:
   ```elixir
   defp publish_event(provider_id, program_ids, count) do
     EnrollmentEvents.bulk_invites_imported(provider_id, program_ids, count)
     |> EventDispatchHelper.dispatch(KlassHero.Enrollment)
   end
   ```

#### Verify GREEN

```bash
mix test test/klass_hero/enrollment/application/use_cases/import_enrollment_csv_test.exs
```

All existing tests should pass (EventDispatchHelper swallows errors). New test should pass (handler runs, tokens assigned).

#### Commit

```bash
git commit -m "feat: publish bulk_invites_imported event after CSV import (#176)"
```

---

### Task 13: Full Suite Verification

**Steps:**

1. Run full test suite:
   ```bash
   mix test
   ```

2. Run precommit:
   ```bash
   mix precommit
   ```
   This runs: `compile --warnings-as-errors`, `deps.unlock --unused`, `format`, `test`

3. Fix any warnings or failures. Common issues:
   - Unused variables (prefix with `_`)
   - Missing imports
   - Compilation warnings from unused aliases

4. If fixes needed:
   ```bash
   git commit -m "fix: resolve warnings for invite email feature (#176)"
   ```

---

## File Map

| # | File | Action |
|---|------|--------|
| 1 | `config/config.exs` | Modify: mailer_defaults, email queue, enrollment port |
| 2 | `config/runtime.exs` | Modify: Resend adapter |
| 3 | `lib/klass_hero/accounts/user_notifier.ex` | Modify: use mailer_defaults |
| 4 | `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex` | Modify: 4 new callbacks |
| 5 | `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex` | Modify: 4 new methods |
| 6 | `lib/klass_hero/enrollment/domain/ports/for_sending_invite_emails.ex` | **Create** |
| 7 | `lib/klass_hero/enrollment/adapters/driven/notifications/invite_email_notifier.ex` | **Create** |
| 8 | `lib/klass_hero/enrollment/domain/events/enrollment_events.ex` | Modify: new factory |
| 9 | `lib/klass_hero/enrollment/adapters/driven/workers/send_invite_email_worker.ex` | **Create** |
| 10 | `lib/klass_hero/enrollment/adapters/driven/events/event_handlers/enqueue_invite_emails.ex` | **Create** |
| 11 | `lib/klass_hero/enrollment/application/use_cases/import_enrollment_csv.ex` | Modify: event dispatch |
| 12 | `lib/klass_hero/application.ex` | Modify: handler registration |

## TDD Verification Checklist

- [ ] Every new function has a test written BEFORE implementation
- [ ] Watched each test fail before writing production code
- [ ] Each failure was "function undefined" or "assertion failed" (not syntax errors)
- [ ] Wrote minimal code to pass — no over-engineering
- [ ] All tests green after each task
- [ ] `mix precommit` passes at the end

# Bulk Enrollment Frontend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the provider-facing UI for bulk enrollment: CSV upload, invite management table with resend/remove, and the backend functions to support them.

**Architecture:** Extend existing `roster_modal` with tabs (Enrolled | Invites). Backend follows existing port → repo → use case → facade pattern. LiveView `allow_upload` for CSV (calls use case directly, no HTTP self-round-trip). TDD throughout: failing test first, minimal code, commit.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto, Oban, existing DDD ports & adapters

**Design doc:** `docs/plans/2026-02-24-bulk-enrollment-frontend-design.md`

---

## Task 1: Repository — `list_by_program/1`

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Test: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs` (create)

**Step 1: Write failing test**

```elixir
defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository,
    as: Repo

  describe "list_by_program/1" do
    test "returns invites for a program ordered by child_last_name" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      {:ok, _} =
        Repo.create_batch([
          invite_attrs(program.id, provider.id, "Zebra", "Alice"),
          invite_attrs(program.id, provider.id, "Adams", "Bob")
        ])

      invites = Repo.list_by_program(program.id)

      assert length(invites) == 2
      assert [first, second] = invites
      assert first.child_last_name == "Adams"
      assert second.child_last_name == "Zebra"
    end

    test "returns empty list for program with no invites" do
      assert Repo.list_by_program(Ecto.UUID.generate()) == []
    end

    test "does not return invites from other programs" do
      provider = insert(:provider_profile_schema)
      program_a = insert(:program_schema, provider_id: provider.id)
      program_b = insert(:program_schema, provider_id: provider.id)

      {:ok, _} = Repo.create_batch([invite_attrs(program_a.id, provider.id, "Smith", "Jane")])
      {:ok, _} = Repo.create_batch([invite_attrs(program_b.id, provider.id, "Jones", "Tom")])

      invites = Repo.list_by_program(program_a.id)

      assert length(invites) == 1
      assert hd(invites).child_last_name == "Smith"
    end
  end

  defp invite_attrs(program_id, provider_id, last_name, first_name) do
    %{
      program_id: program_id,
      provider_id: provider_id,
      child_first_name: first_name,
      child_last_name: last_name,
      child_date_of_birth: ~D[2015-06-15],
      guardian_email: "#{String.downcase(first_name)}@test.com"
    }
  end
end
```

**Step 2: Run test, verify it fails**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs --max-failures 1`

Expected: `UndefinedFunctionError` — `list_by_program/1` does not exist.

**Step 3: Add port callback**

In `for_storing_bulk_enrollment_invites.ex`, add:

```elixir
@callback list_by_program(binary()) :: [struct()]
```

**Step 4: Implement in repository**

In `bulk_enrollment_invite_repository.ex`, add:

```elixir
@impl true
def list_by_program(program_id) when is_binary(program_id) do
  BulkEnrollmentInviteSchema
  |> where([i], i.program_id == ^program_id)
  |> order_by([i], asc: i.child_last_name, asc: i.child_first_name)
  |> Repo.all()
  |> Mapper.to_domain_list()
end
```

**Step 5: Run test, verify it passes**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

Expected: 3 tests, 0 failures.

**Step 6: Commit**

```
feat(enrollment): add list_by_program to invite repository (#176)
```

---

## Task 2: Repository — `count_by_program/1` and `delete/1`

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Modify: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

**Step 1: Write failing tests**

Add to the existing test file:

```elixir
describe "count_by_program/1" do
  test "returns count of invites for a program" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} =
      Repo.create_batch([
        invite_attrs(program.id, provider.id, "Smith", "Jane"),
        invite_attrs(program.id, provider.id, "Jones", "Tom")
      ])

    assert Repo.count_by_program(program.id) == 2
  end

  test "returns 0 for program with no invites" do
    assert Repo.count_by_program(Ecto.UUID.generate()) == 0
  end
end

describe "delete/1" do
  test "deletes an invite by id" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} = Repo.create_batch([invite_attrs(program.id, provider.id, "Smith", "Jane")])
    [invite] = Repo.list_by_program(program.id)

    assert :ok = Repo.delete(invite.id)
    assert Repo.list_by_program(program.id) == []
  end

  test "returns error for non-existent invite" do
    assert {:error, :not_found} = Repo.delete(Ecto.UUID.generate())
  end
end
```

**Step 2: Run tests, verify they fail**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs --max-failures 1`

Expected: `UndefinedFunctionError` — `count_by_program/1` does not exist.

**Step 3: Add port callbacks**

In `for_storing_bulk_enrollment_invites.ex`:

```elixir
@callback count_by_program(binary()) :: non_neg_integer()
@callback delete(binary()) :: :ok | {:error, :not_found}
```

**Step 4: Implement**

In `bulk_enrollment_invite_repository.ex`:

```elixir
@impl true
def count_by_program(program_id) when is_binary(program_id) do
  BulkEnrollmentInviteSchema
  |> where([i], i.program_id == ^program_id)
  |> Repo.aggregate(:count)
end

@impl true
def delete(id) when is_binary(id) do
  case Repo.get(BulkEnrollmentInviteSchema, id) do
    nil -> {:error, :not_found}
    schema -> Repo.delete(schema) |> then(fn {:ok, _} -> :ok end)
  end
end
```

**Step 5: Run tests, verify all pass**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

Expected: All tests pass.

**Step 6: Commit**

```
feat(enrollment): add count_by_program and delete to invite repository (#176)
```

---

## Task 3: Repository — `reset_for_resend/1`

This resets an invite to `pending` status and clears the token + `invite_sent_at`, enabling re-processing by the existing email pipeline.

**Files:**
- Modify: `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex`
- Modify: `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex`
- Modify: `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

**Step 1: Write failing tests**

```elixir
describe "reset_for_resend/1" do
  test "resets invite_sent invite to pending with cleared token" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} = Repo.create_batch([invite_attrs(program.id, provider.id, "Smith", "Jane")])
    [invite] = Repo.list_by_program(program.id)

    # Transition to invite_sent with a token
    {:ok, sent} =
      Repo.transition_status(invite, %{
        status: "invite_sent",
        invite_token: "test-token-123",
        invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    assert sent.status == "invite_sent"

    {:ok, reset} = Repo.reset_for_resend(sent)

    assert reset.status == "pending"
    assert is_nil(reset.invite_token)
    assert is_nil(reset.invite_sent_at)
  end

  test "resets failed invite to pending" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} = Repo.create_batch([invite_attrs(program.id, provider.id, "Smith", "Jane")])
    [invite] = Repo.list_by_program(program.id)

    {:ok, failed} =
      Repo.transition_status(invite, %{status: "failed", error_details: "delivery error"})

    {:ok, reset} = Repo.reset_for_resend(failed)

    assert reset.status == "pending"
    assert is_nil(reset.invite_token)
    assert is_nil(reset.error_details)
  end

  test "rejects reset for enrolled invite" do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} = Repo.create_batch([invite_attrs(program.id, provider.id, "Smith", "Jane")])
    [invite] = Repo.list_by_program(program.id)

    # Walk through the state machine to enrolled
    {:ok, sent} =
      Repo.transition_status(invite, %{
        status: "invite_sent",
        invite_token: "tok",
        invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, reg} =
      Repo.transition_status(sent, %{
        status: "registered",
        registered_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    {:ok, enrolled} =
      Repo.transition_status(reg, %{
        status: "enrolled",
        enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
        enrollment_id: Ecto.UUID.generate()
      })

    assert {:error, :not_resendable} = Repo.reset_for_resend(enrolled)
  end

  test "returns error for non-existent invite" do
    fake = %{id: Ecto.UUID.generate(), status: "pending"}
    assert {:error, :not_found} = Repo.reset_for_resend(fake)
  end
end
```

**Step 2: Run tests, verify they fail**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs --max-failures 1`

Expected: `UndefinedFunctionError` — `reset_for_resend/1` does not exist.

**Step 3: Add port callback**

```elixir
@callback reset_for_resend(struct()) :: {:ok, struct()} | {:error, :not_found | :not_resendable}
```

**Step 4: Implement**

In `bulk_enrollment_invite_repository.ex`:

```elixir
@resendable_statuses ~w(pending invite_sent failed)

@impl true
def reset_for_resend(%{id: id, status: status}) when status in @resendable_statuses do
  case Repo.get(BulkEnrollmentInviteSchema, id) do
    nil ->
      {:error, :not_found}

    schema ->
      # Trigger: invite needs to re-enter the email pipeline
      # Why: clearing token + invite_sent_at makes it eligible for list_pending_without_token
      # Outcome: existing EnqueueInviteEmails picks it up on next dispatch
      changeset =
        Ecto.Changeset.change(schema, %{
          status: "pending",
          invite_token: nil,
          invite_sent_at: nil,
          error_details: nil
        })

      case Repo.update(changeset) do
        {:ok, updated} -> {:ok, Mapper.to_domain(updated)}
        {:error, changeset} -> {:error, changeset}
      end
  end
end

def reset_for_resend(%{id: _id}), do: {:error, :not_resendable}
```

Note: This bypasses `transition_changeset` intentionally — `transition_changeset` only allows `failed → pending` but not `invite_sent → pending` or `pending → pending`. `reset_for_resend` is a dedicated repo function that does its own guard on `@resendable_statuses`, then uses a plain `change/2` since it's clearing fields, not transitioning through the normal state machine.

**Step 5: Run tests, verify all pass**

Run: `mix test test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs`

Expected: All tests pass.

**Step 6: Commit**

```
feat(enrollment): add reset_for_resend to invite repository (#176)
```

---

## Task 4: Use Case — `ListProgramInvites`

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/list_program_invites.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/list_program_invites_test.exs` (create)

**Step 1: Write failing test**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ListProgramInvitesTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.ListProgramInvites
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  describe "execute/1" do
    test "returns invites for a program" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "jane@test.com"
          }
        ])

      {:ok, invites} = ListProgramInvites.execute(program.id)

      assert length(invites) == 1
      assert hd(invites).child_first_name == "Jane"
    end

    test "returns empty list for program with no invites" do
      {:ok, invites} = ListProgramInvites.execute(Ecto.UUID.generate())
      assert invites == []
    end
  end
end
```

**Step 2: Run test, verify it fails**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_invites_test.exs --max-failures 1`

Expected: Module `ListProgramInvites` not found.

**Step 3: Implement**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ListProgramInvites do
  @moduledoc """
  Fetches all bulk enrollment invites for a program.

  Delegates to the invite repository, ordered by child last name.
  """

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary()) :: {:ok, [struct()]}
  def execute(program_id) when is_binary(program_id) do
    {:ok, @invite_repository.list_by_program(program_id)}
  end
end
```

**Step 4: Run test, verify it passes**

Run: `mix test test/klass_hero/enrollment/application/use_cases/list_program_invites_test.exs`

Expected: 2 tests, 0 failures.

**Step 5: Commit**

```
feat(enrollment): add ListProgramInvites use case (#176)
```

---

## Task 5: Use Case — `ResendInvite`

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/resend_invite.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/resend_invite_test.exs` (create)

**Step 1: Write failing test**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ResendInviteTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.ResendInvite
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  setup do
    provider = insert(:provider_profile_schema)
    program = insert(:program_schema, provider_id: provider.id)

    {:ok, _} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Jane",
          child_last_name: "Smith",
          child_date_of_birth: ~D[2015-06-15],
          guardian_email: "jane@test.com"
        }
      ])

    [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)

    # Transition to invite_sent
    {:ok, sent} =
      BulkEnrollmentInviteRepository.transition_status(invite, %{
        status: "invite_sent",
        invite_token: "original-token",
        invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %{invite: sent, program: program, provider: provider}
  end

  describe "execute/1" do
    test "resets invite and dispatches event", %{invite: invite} do
      assert {:ok, reset} = ResendInvite.execute(invite.id)
      assert reset.status == "pending"
      assert is_nil(reset.invite_token)
    end

    test "returns error for non-existent invite" do
      assert {:error, :not_found} = ResendInvite.execute(Ecto.UUID.generate())
    end

    test "returns error for enrolled invite", %{invite: invite} do
      # Walk to enrolled
      {:ok, reg} =
        BulkEnrollmentInviteRepository.transition_status(invite, %{
          status: "registered",
          registered_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, enrolled} =
        BulkEnrollmentInviteRepository.transition_status(reg, %{
          status: "enrolled",
          enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second),
          enrollment_id: Ecto.UUID.generate()
        })

      assert {:error, :not_resendable} = ResendInvite.execute(enrolled.id)
    end
  end
end
```

**Step 2: Run test, verify it fails**

Run: `mix test test/klass_hero/enrollment/application/use_cases/resend_invite_test.exs --max-failures 1`

Expected: Module `ResendInvite` not found.

**Step 3: Implement**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.ResendInvite do
  @moduledoc """
  Resets an invite to pending and dispatches the email pipeline.

  1. Fetch invite by ID
  2. Reset status to pending, clear token + invite_sent_at
  3. Dispatch bulk_invites_imported event for the invite's program

  The existing EnqueueInviteEmails event handler picks up the reset
  invite and re-sends the email with a fresh token.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary()) :: {:ok, struct()} | {:error, :not_found | :not_resendable}
  def execute(invite_id) when is_binary(invite_id) do
    with invite when not is_nil(invite) <- @invite_repository.get_by_id(invite_id),
         {:ok, reset} <- @invite_repository.reset_for_resend(invite) do
      # Trigger: invite reset to pending without token
      # Why: existing email pipeline processes pending invites without tokens
      # Outcome: EnqueueInviteEmails assigns new token + enqueues Oban job
      EnrollmentEvents.bulk_invites_imported(reset.provider_id, [reset.program_id], 1)
      |> EventDispatchHelper.dispatch(KlassHero.Enrollment)

      Logger.info("[ResendInvite] Invite reset and event dispatched",
        invite_id: invite_id,
        program_id: reset.program_id
      )

      {:ok, reset}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**Step 4: Run test, verify it passes**

Run: `mix test test/klass_hero/enrollment/application/use_cases/resend_invite_test.exs`

Expected: 3 tests, 0 failures.

**Step 5: Commit**

```
feat(enrollment): add ResendInvite use case (#176)
```

---

## Task 6: Use Case — `DeleteInvite`

**Files:**
- Create: `lib/klass_hero/enrollment/application/use_cases/delete_invite.ex`
- Test: `test/klass_hero/enrollment/application/use_cases/delete_invite_test.exs` (create)

**Step 1: Write failing test**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.DeleteInviteTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Enrollment.Application.UseCases.DeleteInvite
  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository

  describe "execute/1" do
    test "deletes an invite" do
      provider = insert(:provider_profile_schema)
      program = insert(:program_schema, provider_id: provider.id)

      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "jane@test.com"
          }
        ])

      [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)

      assert :ok = DeleteInvite.execute(invite.id)
      assert BulkEnrollmentInviteRepository.list_by_program(program.id) == []
    end

    test "returns error for non-existent invite" do
      assert {:error, :not_found} = DeleteInvite.execute(Ecto.UUID.generate())
    end
  end
end
```

**Step 2: Run test, verify it fails**

Run: `mix test test/klass_hero/enrollment/application/use_cases/delete_invite_test.exs --max-failures 1`

Expected: Module `DeleteInvite` not found.

**Step 3: Implement**

```elixir
defmodule KlassHero.Enrollment.Application.UseCases.DeleteInvite do
  @moduledoc """
  Deletes a bulk enrollment invite by ID.

  Hard-deletes the staging record. If the invite's email was already
  sent, the link becomes invalid (claim controller returns :not_found).
  """

  @invite_repository Application.compile_env!(:klass_hero, [
                       :enrollment,
                       :for_storing_bulk_enrollment_invites
                     ])

  @spec execute(binary()) :: :ok | {:error, :not_found}
  def execute(invite_id) when is_binary(invite_id) do
    @invite_repository.delete(invite_id)
  end
end
```

**Step 4: Run test, verify it passes**

Run: `mix test test/klass_hero/enrollment/application/use_cases/delete_invite_test.exs`

Expected: 2 tests, 0 failures.

**Step 5: Commit**

```
feat(enrollment): add DeleteInvite use case (#176)
```

---

## Task 7: Facade — Expose new functions on `KlassHero.Enrollment`

**Files:**
- Modify: `lib/klass_hero/enrollment.ex`
- Test: Run existing tests to ensure nothing breaks

**Step 1: Add facade functions**

```elixir
# Bulk Enrollment Management
def list_program_invites(program_id) when is_binary(program_id) do
  ListProgramInvites.execute(program_id)
end

def count_program_invites(program_id) when is_binary(program_id) do
  @invite_repository.count_by_program(program_id)
end

def resend_invite(invite_id) when is_binary(invite_id) do
  ResendInvite.execute(invite_id)
end

def delete_invite(invite_id) when is_binary(invite_id) do
  DeleteInvite.execute(invite_id)
end
```

Add the necessary aliases at the top of `enrollment.ex`:

```elixir
alias KlassHero.Enrollment.Application.UseCases.ListProgramInvites
alias KlassHero.Enrollment.Application.UseCases.ResendInvite
alias KlassHero.Enrollment.Application.UseCases.DeleteInvite
```

Also add `@invite_repository` module attribute if not already present (check — it likely isn't, since the facade delegates to use cases, but `count_by_program` calls repo directly):

```elixir
@invite_repository Application.compile_env!(:klass_hero, [
                     :enrollment,
                     :for_storing_bulk_enrollment_invites
                   ])
```

**Step 2: Run full test suite for enrollment**

Run: `mix test test/klass_hero/enrollment/`

Expected: All tests pass, no warnings.

**Step 3: Commit**

```
feat(enrollment): expose invite management functions on facade (#176)
```

---

## Task 8: Static CSV Template

**Files:**
- Create: `priv/static/downloads/enrollment-import-template.csv`

**Step 1: Create template file**

The headers must match the prefix-matching in `CsvParser` (`@header_mappings`):

```csv
Program,Season,Participant information: First name,Participant information: Last name,Participant information: Date of birth,Parent/guardian information: First name,Parent/guardian information: Last name,Parent/guardian information: Email,Parent/guardian 2 information: First name,Parent/guardian 2 information: Last name,Parent/guardian 2 information: Email,School information: Grade,School information: Name,Medical/allergy information: Medical conditions,Medical/allergy information: Nut allergy,Photography/video release permission: I agree that photos showing my child may be used for marketing,Photography/video release permission: I agree that photos and films of my child may be shared on social media
```

This is a header-only CSV with no data rows — providers fill in their own data.

**Step 2: Verify the template headers work**

Write a quick test or evaluate with `project_eval` that `CsvParser.parse/1` on this template returns `{:error, :empty_csv}` (valid headers, no data rows — not a header error).

**Step 3: Commit**

```
feat(enrollment): add CSV import template for download (#176)
```

---

## Task 9: Roster Modal — Tabbed UI Component

This is the largest frontend task. Rewrite `roster_modal` in `provider_components.ex` with tabs.

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write failing test for tabbed roster modal**

Add to `dashboard_live_test.exs` in the `"programs section"` describe block:

```elixir
describe "roster modal with tabs" do
  setup %{provider: provider} do
    program = insert(:program_schema, provider_id: provider.id, title: "Test Program")
    %{program: program}
  end

  test "shows enrolled and invites tabs when roster opened", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()

    assert has_element?(view, "#roster-modal")
    assert has_element?(view, "#roster-tab-enrolled")
    assert has_element?(view, "#roster-tab-invites")
  end

  test "enrolled tab is active by default", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()

    assert has_element?(view, "#roster-tab-enrolled[aria-selected=true]")
  end

  test "switches to invites tab", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    assert has_element?(view, "#roster-tab-invites[aria-selected=true]")
    assert has_element?(view, "#invites-tab-content")
  end

  test "invites tab shows empty state when no invites", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    assert has_element?(view, "#invites-empty")
  end
end
```

**Step 2: Run tests, verify they fail**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --max-failures 1`

Expected: Fails — `#roster-tab-enrolled` does not exist (old modal has no tabs).

**Step 3: Extend DashboardLive state**

In `dashboard_live.ex`, update the `handle_event("view_roster", ...)`:

- Add `roster_tab: "enrolled"` to the assigns
- Add `roster_program_id: program_id` to the assigns
- Load invite count: `invite_count = Enrollment.count_program_invites(program_id)`
- Load enrolled count from existing `roster_entries`: `enrolled_count = length(roster)`
- Add `roster_invite_count: invite_count`, `roster_enrolled_count: enrolled_count`
- Add `roster_invites: []` (loaded lazily when tab switches)

Add new event handler:

```elixir
def handle_event("switch_roster_tab", %{"tab" => "invites"}, socket) do
  program_id = socket.assigns.roster_program_id

  {:ok, invites} = Enrollment.list_program_invites(program_id)

  {:noreply,
   assign(socket,
     roster_tab: "invites",
     roster_invites: invites
   )}
end

def handle_event("switch_roster_tab", %{"tab" => "enrolled"}, socket) do
  {:noreply, assign(socket, roster_tab: "enrolled")}
end
```

Update `close_roster` handler to also reset `roster_tab`, `roster_invites`, `roster_program_id`, `roster_invite_count`, `roster_enrolled_count`.

**Step 4: Rewrite roster_modal component**

In `provider_components.ex`, update attrs and template:

```elixir
attr :program_name, :string, required: true
attr :program_id, :string, required: true
attr :entries, :list, required: true
attr :invites, :list, required: true
attr :active_tab, :string, default: "enrolled"
attr :enrolled_count, :integer, default: 0
attr :invite_count, :integer, default: 0

def roster_modal(assigns) do
  ~H"""
  <div
    id="roster-modal"
    class="fixed inset-0 z-50 overflow-y-auto"
    role="dialog"
    aria-modal="true"
    phx-window-keydown="close_roster"
    phx-key="Escape"
  >
    <div class="flex min-h-screen items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_roster"></div>
      <div class={[
        "relative bg-white w-full max-w-2xl shadow-xl",
        Theme.rounded(:xl)
      ]}>
        <%!-- Header --%>
        <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
          <h3 class="text-lg font-semibold text-hero-charcoal">
            {gettext("Roster: %{name}", name: @program_name)}
          </h3>
          <button
            type="button"
            phx-click="close_roster"
            class="text-hero-grey-400 hover:text-hero-grey-600"
          >
            <.icon name="hero-x-mark-mini" class="w-5 h-5" />
          </button>
        </div>

        <%!-- Tabs --%>
        <div class="flex border-b border-hero-grey-200" role="tablist">
          <button
            id="roster-tab-enrolled"
            type="button"
            role="tab"
            aria-selected={to_string(@active_tab == "enrolled")}
            phx-click="switch_roster_tab"
            phx-value-tab="enrolled"
            class={[
              "px-4 py-3 text-sm font-medium border-b-2 -mb-px",
              if(@active_tab == "enrolled",
                do: "border-hero-primary text-hero-primary",
                else: "border-transparent text-hero-grey-500 hover:text-hero-charcoal"
              )
            ]}
          >
            {gettext("Enrolled (%{count})", count: @enrolled_count)}
          </button>
          <button
            id="roster-tab-invites"
            type="button"
            role="tab"
            aria-selected={to_string(@active_tab == "invites")}
            phx-click="switch_roster_tab"
            phx-value-tab="invites"
            class={[
              "px-4 py-3 text-sm font-medium border-b-2 -mb-px",
              if(@active_tab == "invites",
                do: "border-hero-primary text-hero-primary",
                else: "border-transparent text-hero-grey-500 hover:text-hero-charcoal"
              )
            ]}
          >
            {gettext("Invites (%{count})", count: @invite_count)}
          </button>
        </div>

        <%!-- Tab Content --%>
        <div class="p-4">
          <%= if @active_tab == "enrolled" do %>
            <div id="enrolled-tab-content">
              <.enrolled_tab entries={@entries} />
            </div>
          <% else %>
            <div id="invites-tab-content">
              <.invites_tab invites={@invites} program_id={@program_id} />
            </div>
          <% end %>
        </div>
      </div>
    </div>
  </div>
  """
end
```

Extract the existing enrolled table into a private `enrolled_tab/1` component. Create a new private `invites_tab/1` component (covered in Task 10).

**Step 5: Pass new assigns through `programs_section`**

In `dashboard_live.ex`, update the `programs_section` attr declarations and the `<.roster_modal>` call to include the new attrs: `program_id`, `invites`, `active_tab`, `enrolled_count`, `invite_count`.

**Step 6: Run tests, verify they pass**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs`

Expected: All tests pass.

**Step 7: Commit**

```
feat(web): add tabbed roster modal with enrolled and invites tabs (#176)
```

---

## Task 10: Invites Tab — Table with Status + Actions

**Files:**
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write failing tests**

```elixir
describe "invites tab content" do
  setup %{provider: provider} do
    program = insert(:program_schema, provider_id: provider.id, title: "Test Program")

    {:ok, _} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Jane",
          child_last_name: "Smith",
          child_date_of_birth: ~D[2015-06-15],
          guardian_email: "parent@test.com"
        }
      ])

    %{program: program}
  end

  test "shows invite rows with child name, email, status", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    assert has_element?(view, "#invites-table")
    html = render(view)
    assert html =~ "Jane Smith"
    assert html =~ "parent@test.com"
  end

  test "shows resend button for pending invite", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    # Pending invites should have resend button
    assert has_element?(view, "[phx-click=resend_invite]")
  end

  test "shows remove button for pending invite", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    assert has_element?(view, "[phx-click=delete_invite]")
  end
end
```

**Step 2: Run tests, verify they fail**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs --max-failures 1`

**Step 3: Implement `invites_tab/1` component**

In `provider_components.ex`:

```elixir
attr :invites, :list, required: true
attr :program_id, :string, required: true

defp invites_tab(assigns) do
  ~H"""
  <div>
    <%!-- Upload + Template buttons --%>
    <div class="flex items-center gap-3 mb-4">
      <button
        id="upload-csv-btn"
        type="button"
        phx-click="open_csv_upload"
        class={[
          "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white",
          Theme.rounded(:lg),
          Theme.gradient(:primary)
        ]}
      >
        <.icon name="hero-arrow-up-tray-mini" class="w-4 h-4" />
        {gettext("Upload CSV")}
      </button>
      <a
        href="/downloads/enrollment-import-template.csv"
        download="enrollment-import-template.csv"
        class={[
          "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-hero-grey-600",
          "border border-hero-grey-300 hover:bg-hero-grey-50",
          Theme.rounded(:lg)
        ]}
      >
        <.icon name="hero-arrow-down-tray-mini" class="w-4 h-4" />
        {gettext("Download Template")}
      </a>
    </div>

    <%!-- Empty state --%>
    <div :if={@invites == []} id="invites-empty" class="text-center py-8">
      <.icon name="hero-envelope" class="w-12 h-12 mx-auto text-hero-grey-300 mb-3" />
      <p class="text-hero-grey-500">
        {gettext("No invites yet. Upload a CSV to invite families.")}
      </p>
    </div>

    <%!-- Invites table --%>
    <table :if={@invites != []} id="invites-table" class="w-full">
      <thead class="bg-hero-grey-50 border-b border-hero-grey-200">
        <tr>
          <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
            {gettext("Child Name")}
          </th>
          <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
            {gettext("Guardian Email")}
          </th>
          <th class="px-3 py-2 text-left text-xs font-semibold text-hero-grey-500 uppercase">
            {gettext("Status")}
          </th>
          <th class="px-3 py-2 text-right text-xs font-semibold text-hero-grey-500 uppercase">
            {gettext("Actions")}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-hero-grey-200">
        <tr :for={invite <- @invites} id={"invite-#{invite.id}"} class="hover:bg-hero-grey-50">
          <td class="px-3 py-3 text-sm text-hero-charcoal font-medium">
            {invite.child_first_name} {invite.child_last_name}
          </td>
          <td class="px-3 py-3 text-sm text-hero-grey-500">
            {invite.guardian_email}
          </td>
          <td class="px-3 py-3">
            <.status_pill color={invite_status_color(invite.status)}>
              {invite_status_label(invite.status)}
            </.status_pill>
          </td>
          <td class="px-3 py-3 text-right">
            <div class="flex items-center justify-end gap-1">
              <.action_button
                :if={invite.status in ~w(pending invite_sent failed)}
                icon="hero-arrow-path-mini"
                title={gettext("Resend Invite")}
                phx-click="resend_invite"
                phx-value-id={invite.id}
              />
              <.action_button
                :if={invite.status in ~w(pending invite_sent failed)}
                icon="hero-trash-mini"
                title={gettext("Remove")}
                phx-click="delete_invite"
                phx-value-id={invite.id}
              />
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
  """
end
```

Add status helper functions:

```elixir
defp invite_status_color("pending"), do: "warning"
defp invite_status_color("invite_sent"), do: "info"
defp invite_status_color("registered"), do: "purple"
defp invite_status_color("enrolled"), do: "success"
defp invite_status_color("failed"), do: "danger"
defp invite_status_color(_), do: "info"

defp invite_status_label("pending"), do: gettext("Pending")
defp invite_status_label("invite_sent"), do: gettext("Sent")
defp invite_status_label("registered"), do: gettext("Registered")
defp invite_status_label("enrolled"), do: gettext("Enrolled")
defp invite_status_label("failed"), do: gettext("Failed")
defp invite_status_label(status), do: status |> to_string() |> String.capitalize()
```

**Step 4: Add event handlers in DashboardLive**

```elixir
def handle_event("resend_invite", %{"id" => invite_id}, socket) do
  case Enrollment.resend_invite(invite_id) do
    {:ok, _} ->
      {:ok, invites} = Enrollment.list_program_invites(socket.assigns.roster_program_id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Invite resent successfully."))
       |> assign(roster_invites: invites)}

    {:error, :not_resendable} ->
      {:noreply, put_flash(socket, :error, gettext("This invite cannot be resent."))}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, gettext("Failed to resend invite."))}
  end
end

def handle_event("delete_invite", %{"id" => invite_id}, socket) do
  case Enrollment.delete_invite(invite_id) do
    :ok ->
      program_id = socket.assigns.roster_program_id
      {:ok, invites} = Enrollment.list_program_invites(program_id)
      invite_count = Enrollment.count_program_invites(program_id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Invite removed."))
       |> assign(roster_invites: invites, roster_invite_count: invite_count)}

    {:error, :not_found} ->
      {:noreply, put_flash(socket, :error, gettext("Invite not found."))}
  end
end
```

**Step 5: Run tests, verify they pass**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 6: Commit**

```
feat(web): add invites tab with status table and resend/remove actions (#176)
```

---

## Task 11: CSV Upload via LiveView

**Files:**
- Modify: `lib/klass_hero_web/live/provider/dashboard_live.ex`
- Modify: `lib/klass_hero_web/components/provider_components.ex`
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write failing tests**

```elixir
describe "CSV upload in invites tab" do
  setup %{provider: provider} do
    program =
      insert(:program_schema, provider_id: provider.id, title: "Ballsports & Parkour")

    %{program: program}
  end

  test "successful CSV upload shows success flash", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    csv =
      "Program,Participant information: First name,Participant information: Last name," <>
        "Participant information: Date of birth,Parent/guardian information: Email\r\n" <>
        "Ballsports & Parkour,Jane,Smith,6/15/2015,parent@test.com\r\n"

    csv_upload =
      file_input(view, "#csv-upload-form", :csv_file, [
        %{
          name: "test.csv",
          content: csv,
          type: "text/csv"
        }
      ])

    render_upload(csv_upload, "test.csv")
    render(view) |> then(fn html -> assert html =~ "parent@test.com" || html =~ "Imported" end)
  end
end
```

Note: The exact assertion shape may need adjusting once the upload form structure is finalized. The key behaviors to test: file accepted, use case called, invites list refreshed on success, error display on failure.

**Step 2: Run tests, verify they fail**

**Step 3: Add `allow_upload` to DashboardLive mount**

In `mount/3`, add the CSV upload config (only active when roster is open — but `allow_upload` is fine to register at mount; the form only renders when roster is open):

```elixir
|> allow_upload(:csv_file,
  accept: ~w(.csv),
  max_entries: 1,
  max_file_size: 2_000_000
)
```

**Step 4: Add upload form to invites_tab component**

Replace the "Upload CSV" button with a form that wraps `<.live_file_input>`:

```elixir
<form id="csv-upload-form" phx-change="validate_csv_upload" phx-submit="import_csv" class="inline">
  <label
    for={@uploads.csv_file.ref}
    class={[
      "inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white cursor-pointer",
      Theme.rounded(:lg),
      Theme.gradient(:primary)
    ]}
  >
    <.icon name="hero-arrow-up-tray-mini" class="w-4 h-4" />
    {gettext("Upload CSV")}
  </label>
  <.live_file_input upload={@uploads.csv_file} class="hidden" />

  <%!-- Show selected file + import button --%>
  <div :for={entry <- @uploads.csv_file.entries} class="mt-3 flex items-center gap-3">
    <span class="text-sm text-hero-charcoal">{entry.client_name}</span>
    <button
      type="submit"
      class={[
        "px-3 py-1.5 text-sm font-medium text-white",
        Theme.rounded(:lg),
        Theme.gradient(:primary)
      ]}
    >
      {gettext("Import")}
    </button>
    <button
      type="button"
      phx-click="cancel_csv_upload"
      phx-value-ref={entry.ref}
      class="text-sm text-hero-grey-500 hover:text-hero-charcoal"
    >
      {gettext("Cancel")}
    </button>
  </div>

  <%!-- Upload errors --%>
  <div :for={err <- upload_errors(@uploads.csv_file)} class="mt-2 text-sm text-red-600">
    {upload_error_to_string(err)}
  </div>
</form>
```

Pass `@uploads` through from `programs_section` → `roster_modal` → `invites_tab`.

**Step 5: Add event handlers**

```elixir
def handle_event("validate_csv_upload", _params, socket) do
  {:noreply, socket}
end

def handle_event("cancel_csv_upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :csv_file, ref)}
end

def handle_event("import_csv", _params, socket) do
  provider_id = socket.assigns.provider.id
  program_id = socket.assigns.roster_program_id

  # Consume the uploaded file and read its binary content
  [csv_binary] =
    consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
      {:ok, File.read!(path)}
    end)

  case Enrollment.import_enrollment_csv(provider_id, csv_binary) do
    {:ok, %{created: count}} ->
      {:ok, invites} = Enrollment.list_program_invites(program_id)
      invite_count = Enrollment.count_program_invites(program_id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Imported %{count} families.", count: count))
       |> assign(
         roster_invites: invites,
         roster_invite_count: invite_count,
         import_errors: nil
       )}

    {:error, error_report} ->
      {:noreply, assign(socket, import_errors: error_report)}
  end
end
```

**Step 6: Add error display in invites_tab**

Add an `import_errors` attr to `invites_tab` and render errors when present:

```elixir
<div :if={@import_errors} id="import-errors" class={[
  "mt-3 p-3 bg-red-50 border border-red-200 text-sm text-red-700",
  Theme.rounded(:lg)
]}>
  <p class="font-semibold mb-2">{gettext("Import failed")}</p>
  <%!-- Render validation_errors, parse_errors, duplicate_errors --%>
  <ul class="list-disc pl-5 space-y-1">
    <li :for={{row, msg} <- format_import_errors(@import_errors)}>
      {msg}
    </li>
  </ul>
</div>
```

Add a helper to format the error report into displayable rows. The error report shape from `ImportEnrollmentCsv` is `%{parse_errors: [...], validation_errors: [...], duplicate_errors: [...]}`.

**Step 7: Run tests, verify they pass**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 8: Commit**

```
feat(web): add CSV upload to invites tab with error display (#176)
```

---

## Task 12: Resend + Delete Integration Tests

**Files:**
- Modify: `test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 1: Write tests for resend and delete actions**

```elixir
describe "invite actions" do
  setup %{provider: provider} do
    program = insert(:program_schema, provider_id: provider.id, title: "Test Program")

    {:ok, _} =
      BulkEnrollmentInviteRepository.create_batch([
        %{
          program_id: program.id,
          provider_id: provider.id,
          child_first_name: "Jane",
          child_last_name: "Smith",
          child_date_of_birth: ~D[2015-06-15],
          guardian_email: "parent@test.com"
        }
      ])

    %{program: program}
  end

  test "resend invite shows success flash", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    html = view |> element("[phx-click=resend_invite]") |> render_click()

    assert html =~ "Invite resent"
  end

  test "delete invite removes row from table", %{conn: conn, program: program} do
    {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

    view |> element("#view-roster-#{program.id}") |> render_click()
    view |> element("#roster-tab-invites") |> render_click()

    assert has_element?(view, "#invites-table")

    view |> element("[phx-click=delete_invite]") |> render_click()

    # After deletion, table should be gone (only had 1 invite)
    assert has_element?(view, "#invites-empty")
  end
end
```

**Step 2: Run tests, verify they pass (already implemented in Task 10)**

Run: `mix test test/klass_hero_web/live/provider/dashboard_live_test.exs`

**Step 3: Commit**

```
test(web): add integration tests for invite resend and delete (#176)
```

---

## Task 13: Final — Precommit + Push

**Step 1: Run full precommit**

```bash
mix precommit
```

Expected: Compiles with 0 warnings, format clean, all tests pass.

**Step 2: Fix any issues found**

**Step 3: Push**

```bash
git push
```

---

## File Change Summary

| # | File | Action |
|---|---|---|
| 1 | `lib/klass_hero/enrollment/domain/ports/for_storing_bulk_enrollment_invites.ex` | Modify: add 4 callbacks |
| 2 | `lib/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository.ex` | Modify: add 4 functions |
| 3 | `test/klass_hero/enrollment/adapters/driven/persistence/repositories/bulk_enrollment_invite_repository_test.exs` | Create |
| 4 | `lib/klass_hero/enrollment/application/use_cases/list_program_invites.ex` | Create |
| 5 | `test/klass_hero/enrollment/application/use_cases/list_program_invites_test.exs` | Create |
| 6 | `lib/klass_hero/enrollment/application/use_cases/resend_invite.ex` | Create |
| 7 | `test/klass_hero/enrollment/application/use_cases/resend_invite_test.exs` | Create |
| 8 | `lib/klass_hero/enrollment/application/use_cases/delete_invite.ex` | Create |
| 9 | `test/klass_hero/enrollment/application/use_cases/delete_invite_test.exs` | Create |
| 10 | `lib/klass_hero/enrollment.ex` | Modify: add 4 facade functions + aliases |
| 11 | `priv/static/downloads/enrollment-import-template.csv` | Create |
| 12 | `lib/klass_hero_web/components/provider_components.ex` | Modify: rewrite roster_modal with tabs |
| 13 | `lib/klass_hero_web/live/provider/dashboard_live.ex` | Modify: new assigns + event handlers |
| 14 | `test/klass_hero_web/live/provider/dashboard_live_test.exs` | Modify: add tab + invite tests |

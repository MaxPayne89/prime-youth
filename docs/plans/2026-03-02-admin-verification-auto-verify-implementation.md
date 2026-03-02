# Auto-Verify Provider on Document Approval — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When admin approves all verification documents, auto-verify the provider. When any doc is rejected after verification, auto-unverify.

**Architecture:** Domain events within Provider context. `ApproveVerificationDocument` and `RejectVerificationDocument` dispatch domain events. A handler on Provider's `DomainEventBus` evaluates all document statuses and calls `VerifyProvider`/`UnverifyProvider` accordingly.

**Tech Stack:** Elixir, Phoenix PubSub, DomainEventBus, EventDispatchHelper

---

### Task 1: Create the CheckProviderVerificationStatus handler

**Files:**
- Create: `lib/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status.ex`
- Test: `test/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status_test.exs`

**Step 1: Write the failing test**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Events.EventHandlers.CheckProviderVerificationStatusTest do
  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider.Adapters.Driven.Events.EventHandlers.CheckProviderVerificationStatus
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.ProviderFixtures
  alias KlassHero.Shared.Domain.Events.DomainEvent

  setup do
    setup_test_integration_events()
    provider = ProviderFixtures.provider_profile_fixture()
    admin = AccountsFixtures.user_fixture(%{is_admin: true})
    %{provider: provider, admin: admin}
  end

  describe "handle/1 for :verification_document_approved" do
    test "verifies provider when all docs approved", %{provider: provider, admin: admin} do
      doc = create_approved_document(provider.id, admin.id)

      event = build_doc_event(:verification_document_approved, doc, admin.id)
      assert :ok = CheckProviderVerificationStatus.handle(event)

      assert_integration_event_published(:provider_verified)
    end

    test "does not verify when some docs still pending", %{provider: provider, admin: admin} do
      _approved = create_approved_document(provider.id, admin.id)
      pending = create_pending_document(provider.id)

      event = build_doc_event(:verification_document_approved, pending, admin.id)
      assert :ok = CheckProviderVerificationStatus.handle(event)

      assert_no_integration_events_published()
    end

    test "does not verify when some docs rejected", %{provider: provider, admin: admin} do
      _approved = create_approved_document(provider.id, admin.id)
      rejected = create_rejected_document(provider.id, admin.id)

      event = build_doc_event(:verification_document_approved, rejected, admin.id)
      assert :ok = CheckProviderVerificationStatus.handle(event)

      assert_no_integration_events_published()
    end
  end

  describe "handle/1 for :verification_document_rejected" do
    test "unverifies provider when provider was verified", %{provider: provider, admin: admin} do
      # Verify the provider first
      _doc = create_approved_document(provider.id, admin.id)
      {:ok, _} = KlassHero.Provider.verify_provider(provider.id, admin.id)
      clear_integration_events()

      # Now reject a doc
      rejected = create_rejected_document(provider.id, admin.id)
      event = build_doc_event(:verification_document_rejected, rejected, admin.id)
      assert :ok = CheckProviderVerificationStatus.handle(event)

      assert_integration_event_published(:provider_unverified)
    end

    test "no-op when provider was not verified", %{provider: provider, admin: admin} do
      rejected = create_rejected_document(provider.id, admin.id)
      event = build_doc_event(:verification_document_rejected, rejected, admin.id)
      assert :ok = CheckProviderVerificationStatus.handle(event)

      assert_no_integration_events_published()
    end
  end

  # Helpers

  defp build_doc_event(event_type, doc, reviewer_id) do
    DomainEvent.new(
      event_type,
      doc.id,
      :verification_document,
      %{provider_id: doc.provider_profile_id, reviewer_id: reviewer_id}
    )
  end

  defp create_pending_document(provider_id) do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: "business_registration",
        file_url: "verification-docs/test.pdf",
        original_filename: "doc.pdf"
      })

    {:ok, persisted} = VerificationDocumentRepository.create(doc)
    persisted
  end

  defp create_approved_document(provider_id, reviewer_id) do
    doc = create_pending_document(provider_id)
    {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)
    {:ok, persisted} = VerificationDocumentRepository.update(approved)
    persisted
  end

  defp create_rejected_document(provider_id, reviewer_id) do
    doc = create_pending_document(provider_id)
    {:ok, rejected} = VerificationDocument.reject(doc, reviewer_id, "Invalid document")
    {:ok, persisted} = VerificationDocumentRepository.update(rejected)
    persisted
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status_test.exs --max-failures 1`
Expected: FAIL — module `CheckProviderVerificationStatus` not found

**Step 3: Write minimal implementation**

```elixir
defmodule KlassHero.Provider.Adapters.Driven.Events.EventHandlers.CheckProviderVerificationStatus do
  @moduledoc """
  Domain event handler that bridges document approval to provider verification.

  When a verification document is approved, checks if ALL the provider's documents
  are now approved. If so, auto-verifies the provider via VerifyProvider use case.

  When a document is rejected, checks if the provider was previously verified.
  If so, auto-unverifies via UnverifyProvider use case.

  Registered on the Provider DomainEventBus for:
  - :verification_document_approved
  - :verification_document_rejected
  """

  alias KlassHero.Provider.Application.UseCases.Providers.UnverifyProvider
  alias KlassHero.Provider.Application.UseCases.Providers.VerifyProvider
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @doc_repository Application.compile_env!(:klass_hero, [
                    :provider,
                    :for_storing_verification_documents
                  ])

  @profile_repository Application.compile_env!(:klass_hero, [
                        :provider,
                        :for_storing_provider_profiles
                      ])

  @doc """
  Handles verification document domain events.

  For :verification_document_approved — checks all docs, verifies provider if all approved.
  For :verification_document_rejected — unverifies provider if currently verified.
  """
  @spec handle(DomainEvent.t()) :: :ok
  def handle(%DomainEvent{event_type: :verification_document_approved, payload: payload}) do
    %{provider_id: provider_id, reviewer_id: reviewer_id} = payload

    # Trigger: a document was just approved
    # Why: provider should be auto-verified when ALL their docs are approved
    # Outcome: if all docs approved, VerifyProvider is called (publishes integration event)
    with {:ok, docs} <- @doc_repository.get_by_provider(provider_id),
         true <- all_approved?(docs) do
      case VerifyProvider.execute(%{provider_id: provider_id, admin_id: reviewer_id}) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("Auto-verify failed for provider #{provider_id}: #{inspect(reason)}")
          :ok
      end
    else
      _ -> :ok
    end
  end

  def handle(%DomainEvent{event_type: :verification_document_rejected, payload: payload}) do
    %{provider_id: provider_id, reviewer_id: reviewer_id} = payload

    # Trigger: a document was rejected
    # Why: a verified provider with a rejected doc violates the invariant
    # Outcome: if provider was verified, UnverifyProvider is called
    with {:ok, profile} <- @profile_repository.get(provider_id),
         true <- profile.verified do
      case UnverifyProvider.execute(%{provider_id: provider_id, admin_id: reviewer_id}) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("Auto-unverify failed for provider #{provider_id}: #{inspect(reason)}")
          :ok
      end
    else
      _ -> :ok
    end
  end

  # Trigger: need to check if every document for a provider has been approved
  # Why: provider verification requires ALL documents reviewed and approved
  # Outcome: returns true only when list is non-empty and every doc is :approved
  defp all_approved?([]), do: false
  defp all_approved?(docs), do: Enum.all?(docs, &(&1.status == :approved))
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status_test.exs`
Expected: all tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status.ex test/klass_hero/provider/adapters/driven/events/event_handlers/check_provider_verification_status_test.exs
git commit -m "feat: add CheckProviderVerificationStatus domain event handler

Bridges document approval/rejection to provider verification status.
When all docs approved, auto-verifies provider. When any doc rejected
after verification, auto-unverifies. Closes gap in issue #244."
```

---

### Task 2: Add domain event dispatch to ApproveVerificationDocument

**Files:**
- Modify: `lib/klass_hero/provider/application/use_cases/verification/approve_verification_document.ex`
- Test: `test/klass_hero/provider/application/use_cases/verification/document_review_test.exs` (existing)

**Step 1: Write the failing test**

Add to existing `document_review_test.exs`, in the `ApproveVerificationDocument.execute/1` describe block:

```elixir
# Add to setup:
#   setup_test_events()

test "dispatches :verification_document_approved domain event", %{admin: admin, document: doc} do
  params = %{document_id: doc.id, reviewer_id: admin.id}
  assert {:ok, approved} = ApproveVerificationDocument.execute(params)

  event = assert_event_published(:verification_document_approved)
  assert event.aggregate_id == doc.id
  assert event.payload.provider_id == approved.provider_profile_id
  assert event.payload.reviewer_id == admin.id
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/application/use_cases/verification/document_review_test.exs --max-failures 1`
Expected: FAIL — no `:verification_document_approved` event published

**Step 3: Modify ApproveVerificationDocument**

Update `lib/klass_hero/provider/application/use_cases/verification/approve_verification_document.ex`:

Add aliases at top:
```elixir
alias KlassHero.Shared.Domain.Events.DomainEvent
alias KlassHero.Shared.EventDispatchHelper
```

Replace the `execute` function body:
```elixir
def execute(%{document_id: document_id, reviewer_id: reviewer_id}) do
  with {:ok, document} <- @repository.get(document_id),
       {:ok, approved} <- VerificationDocument.approve(document, reviewer_id),
       {:ok, persisted} <- @repository.update(approved) do
    # Trigger: document successfully approved and persisted
    # Why: other handlers need to evaluate provider verification status
    # Outcome: domain event dispatched (fire-and-forget), approved doc returned
    dispatch_event(persisted, reviewer_id)
    {:ok, persisted}
  end
end

defp dispatch_event(doc, reviewer_id) do
  DomainEvent.new(
    :verification_document_approved,
    doc.id,
    :verification_document,
    %{provider_id: doc.provider_profile_id, reviewer_id: reviewer_id}
  )
  |> EventDispatchHelper.dispatch(KlassHero.Provider)
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/provider/application/use_cases/verification/document_review_test.exs`
Expected: all tests PASS (including existing tests)

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/application/use_cases/verification/approve_verification_document.ex test/klass_hero/provider/application/use_cases/verification/document_review_test.exs
git commit -m "feat: dispatch domain event on document approval

ApproveVerificationDocument now dispatches :verification_document_approved
domain event after persisting. Fire-and-forget via EventDispatchHelper."
```

---

### Task 3: Add domain event dispatch to RejectVerificationDocument

**Files:**
- Modify: `lib/klass_hero/provider/application/use_cases/verification/reject_verification_document.ex`
- Test: `test/klass_hero/provider/application/use_cases/verification/document_review_test.exs` (existing)

**Step 1: Write the failing test**

Add to existing `document_review_test.exs`, in the `RejectVerificationDocument.execute/1` describe block:

```elixir
test "dispatches :verification_document_rejected domain event", %{admin: admin, document: doc} do
  params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Expired document"}
  assert {:ok, rejected} = RejectVerificationDocument.execute(params)

  event = assert_event_published(:verification_document_rejected)
  assert event.aggregate_id == doc.id
  assert event.payload.provider_id == rejected.provider_profile_id
  assert event.payload.reviewer_id == admin.id
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/klass_hero/provider/application/use_cases/verification/document_review_test.exs --max-failures 1`
Expected: FAIL — no `:verification_document_rejected` event published

**Step 3: Modify RejectVerificationDocument**

Update `lib/klass_hero/provider/application/use_cases/verification/reject_verification_document.ex`:

Add aliases at top:
```elixir
alias KlassHero.Shared.Domain.Events.DomainEvent
alias KlassHero.Shared.EventDispatchHelper
```

Replace the `execute` function body:
```elixir
def execute(%{document_id: document_id, reviewer_id: reviewer_id, reason: reason}) do
  # Trigger: reason may be nil or empty string
  # Why: rejection requires explanation for provider to understand and fix
  # Outcome: early validation prevents rejecting without reason
  with :ok <- validate_reason(reason),
       {:ok, document} <- @repository.get(document_id),
       {:ok, rejected} <- VerificationDocument.reject(document, reviewer_id, reason),
       {:ok, persisted} <- @repository.update(rejected) do
    # Trigger: document successfully rejected and persisted
    # Why: other handlers need to evaluate provider verification status
    # Outcome: domain event dispatched (fire-and-forget), rejected doc returned
    dispatch_event(persisted, reviewer_id)
    {:ok, persisted}
  end
end

defp dispatch_event(doc, reviewer_id) do
  DomainEvent.new(
    :verification_document_rejected,
    doc.id,
    :verification_document,
    %{provider_id: doc.provider_profile_id, reviewer_id: reviewer_id}
  )
  |> EventDispatchHelper.dispatch(KlassHero.Provider)
end
```

**Step 4: Run tests**

Run: `mix test test/klass_hero/provider/application/use_cases/verification/document_review_test.exs`
Expected: all tests PASS

**Step 5: Commit**

```bash
git add lib/klass_hero/provider/application/use_cases/verification/reject_verification_document.ex test/klass_hero/provider/application/use_cases/verification/document_review_test.exs
git commit -m "feat: dispatch domain event on document rejection

RejectVerificationDocument now dispatches :verification_document_rejected
domain event after persisting. Fire-and-forget via EventDispatchHelper."
```

---

### Task 4: Register handlers on Provider DomainEventBus

**Files:**
- Modify: `lib/klass_hero/application.ex:88-91`

**Step 1: No separate test — verified by integration test in Task 5**

**Step 2: Modify application.ex**

Replace the Provider DomainEventBus registration (lines 88-91):

```elixir
# Before:
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus, context: KlassHero.Provider, handlers: []},
  id: :provider_domain_event_bus
),

# After:
Supervisor.child_spec(
  {KlassHero.Shared.DomainEventBus,
   context: KlassHero.Provider,
   handlers: [
     {:verification_document_approved,
      {KlassHero.Provider.Adapters.Driven.Events.EventHandlers.CheckProviderVerificationStatus,
       :handle}},
     {:verification_document_rejected,
      {KlassHero.Provider.Adapters.Driven.Events.EventHandlers.CheckProviderVerificationStatus,
       :handle}}
   ]},
  id: :provider_domain_event_bus
),
```

**Step 3: Compile to verify no warnings**

Run: `mix compile --warnings-as-errors`
Expected: compiles clean

**Step 4: Commit**

```bash
git add lib/klass_hero/application.ex
git commit -m "feat: register verification status handlers on Provider DomainEventBus

Wires :verification_document_approved and :verification_document_rejected
events to CheckProviderVerificationStatus handler."
```

---

### Task 5: End-to-end integration test

**Files:**
- Create: `test/klass_hero/provider/application/use_cases/verification/auto_verify_integration_test.exs`

**Step 1: Write integration test**

```elixir
defmodule KlassHero.Provider.Application.UseCases.Verification.AutoVerifyIntegrationTest do
  @moduledoc """
  Integration test for the full flow: approve all docs → provider verified.
  Reject a doc → provider unverified.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.EventTestHelper

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Provider.Application.UseCases.Verification.ApproveVerificationDocument
  alias KlassHero.Provider.Application.UseCases.Verification.RejectVerificationDocument
  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.ProviderFixtures

  setup do
    setup_test_integration_events()
    provider = ProviderFixtures.provider_profile_fixture()
    admin = AccountsFixtures.user_fixture(%{is_admin: true})
    %{provider: provider, admin: admin}
  end

  describe "full approval flow" do
    test "approving all documents auto-verifies provider", %{provider: provider, admin: admin} do
      doc1 = create_pending_document(provider.id, "business_registration")
      doc2 = create_pending_document(provider.id, "insurance_certificate")

      # Approve first doc — provider should NOT be verified yet
      ApproveVerificationDocument.execute(%{document_id: doc1.id, reviewer_id: admin.id})

      {:ok, profile} = ProviderProfileRepository.get(provider.id)
      assert profile.verified == false

      # Approve second doc — NOW provider should be verified
      ApproveVerificationDocument.execute(%{document_id: doc2.id, reviewer_id: admin.id})

      {:ok, profile} = ProviderProfileRepository.get(provider.id)
      assert profile.verified == true
      assert profile.verified_at != nil
    end

    test "single document approval auto-verifies provider", %{provider: provider, admin: admin} do
      doc = create_pending_document(provider.id, "business_registration")

      ApproveVerificationDocument.execute(%{document_id: doc.id, reviewer_id: admin.id})

      {:ok, profile} = ProviderProfileRepository.get(provider.id)
      assert profile.verified == true
    end
  end

  describe "rejection after verification" do
    test "rejecting a doc after verification auto-unverifies provider", %{
      provider: provider,
      admin: admin
    } do
      doc1 = create_pending_document(provider.id, "business_registration")
      doc2 = create_pending_document(provider.id, "insurance_certificate")

      # Approve both to get verified
      ApproveVerificationDocument.execute(%{document_id: doc1.id, reviewer_id: admin.id})
      ApproveVerificationDocument.execute(%{document_id: doc2.id, reviewer_id: admin.id})

      {:ok, profile} = ProviderProfileRepository.get(provider.id)
      assert profile.verified == true

      # Now submit a new doc and have it rejected
      doc3 = create_pending_document(provider.id, "tax_certificate")

      RejectVerificationDocument.execute(%{
        document_id: doc3.id,
        reviewer_id: admin.id,
        reason: "Expired"
      })

      {:ok, profile} = ProviderProfileRepository.get(provider.id)
      assert profile.verified == false
    end
  end

  defp create_pending_document(provider_id, doc_type) do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: doc_type,
        file_url: "verification-docs/#{Ecto.UUID.generate()}.pdf",
        original_filename: "#{doc_type}.pdf"
      })

    {:ok, persisted} = VerificationDocumentRepository.create(doc)
    persisted
  end
end
```

**Step 2: Run integration test**

Run: `mix test test/klass_hero/provider/application/use_cases/verification/auto_verify_integration_test.exs`
Expected: all tests PASS

**Step 3: Commit**

```bash
git add test/klass_hero/provider/application/use_cases/verification/auto_verify_integration_test.exs
git commit -m "test: add integration tests for auto-verify/unverify flow

Covers: all docs approved → provider verified, partial approval → not
verified, rejection after verification → provider unverified."
```

---

### Task 6: Run full test suite and verify

**Step 1: Run precommit**

Run: `mix precommit`
Expected: compile clean (no warnings), format clean, all tests PASS

**Step 2: Fix any failures**

If warnings or test failures, fix them before proceeding.

**Step 3: Final commit if any fixes needed**

---

### Task 7: Push and close issue

**Step 1: Push branch**

```bash
git push -u origin bug/244-admin-verification-review
```

**Step 2: Create PR**

```bash
gh pr create --title "fix: auto-verify provider when all docs approved" --body "$(cat <<'EOF'
## Summary
- Fixes #244 — provider verification stays pending after admin approves documents
- Adds domain event dispatch to `ApproveVerificationDocument` and `RejectVerificationDocument`
- New `CheckProviderVerificationStatus` handler auto-verifies/unverifies provider
- Registered on Provider `DomainEventBus` following established codebase patterns

## Test plan
- [ ] Unit tests for handler (all approved → verify, partial → no-op, rejected → unverify)
- [ ] Use case tests verify domain events are dispatched
- [ ] Integration test: full approve-all → verify → reject → unverify flow
- [ ] `mix precommit` passes (compile, format, tests)
EOF
)"
```

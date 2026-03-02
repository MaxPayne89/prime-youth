defmodule KlassHero.Provider.Application.UseCases.Verification.DocumentReviewTest do
  use KlassHero.DataCase, async: false

  import KlassHero.EventTestHelper

  alias KlassHero.AccountsFixtures
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Provider.Application.UseCases.Verification.ApproveVerificationDocument
  alias KlassHero.Provider.Application.UseCases.Verification.RejectVerificationDocument
  alias KlassHero.ProviderFixtures
  alias KlassHero.Shared.Adapters.Driven.Events.TestEventPublisher
  alias KlassHero.Shared.DomainEventBus

  setup do
    setup_test_events()

    # Trigger: EventDispatchHelper dispatches via DomainEventBus, not the publisher port
    # Why: capture events into TestEventPublisher so assert_event_published works
    # Outcome: domain bus events become visible to EventTestHelper assertions
    DomainEventBus.subscribe(KlassHero.Provider, :verification_document_approved, fn event ->
      TestEventPublisher.publish(event)
      :ok
    end)

    DomainEventBus.subscribe(KlassHero.Provider, :verification_document_rejected, fn event ->
      TestEventPublisher.publish(event)
      :ok
    end)

    provider = ProviderFixtures.provider_profile_fixture()
    admin = AccountsFixtures.user_fixture(%{is_admin: true})
    doc = ProviderFixtures.verification_document_fixture(provider_id: provider.id)
    %{provider: provider, admin: admin, document: doc}
  end

  describe "ApproveVerificationDocument.execute/1" do
    test "approves pending document", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:ok, approved} = ApproveVerificationDocument.execute(params)
      assert approved.status == :approved
      assert approved.reviewed_by_id == admin.id
      assert approved.reviewed_at != nil
    end

    test "persists approved document to database", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:ok, _approved} = ApproveVerificationDocument.execute(params)

      # Verify the document was persisted
      assert {:ok, reloaded} = VerificationDocumentRepository.get(doc.id)
      assert reloaded.status == :approved
      assert reloaded.reviewed_by_id == admin.id
    end

    test "fails for non-existent document", %{admin: admin} do
      params = %{document_id: Ecto.UUID.generate(), reviewer_id: admin.id}
      assert {:error, :not_found} = ApproveVerificationDocument.execute(params)
    end

    test "fails for already approved document", %{admin: admin, document: doc} do
      # First approval
      params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:ok, _approved} = ApproveVerificationDocument.execute(params)

      # Second approval should fail
      assert {:error, :document_not_pending} = ApproveVerificationDocument.execute(params)
    end

    test "fails for already rejected document", %{admin: admin, document: doc} do
      # First reject
      reject_params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Invalid"}
      assert {:ok, _rejected} = RejectVerificationDocument.execute(reject_params)

      # Then try to approve should fail
      approve_params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:error, :document_not_pending} = ApproveVerificationDocument.execute(approve_params)
    end

    test "dispatches :verification_document_approved domain event", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:ok, approved} = ApproveVerificationDocument.execute(params)

      event = assert_event_published(:verification_document_approved)
      assert event.aggregate_id == doc.id
      assert event.payload.provider_id == approved.provider_profile_id
      assert event.payload.reviewer_id == admin.id
    end
  end

  describe "RejectVerificationDocument.execute/1" do
    test "rejects pending document with reason", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Document is expired"}
      assert {:ok, rejected} = RejectVerificationDocument.execute(params)
      assert rejected.status == :rejected
      assert rejected.rejection_reason == "Document is expired"
      assert rejected.reviewed_by_id == admin.id
      assert rejected.reviewed_at != nil
    end

    test "persists rejected document to database", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Unclear image"}
      assert {:ok, _rejected} = RejectVerificationDocument.execute(params)

      # Verify the document was persisted
      assert {:ok, reloaded} = VerificationDocumentRepository.get(doc.id)
      assert reloaded.status == :rejected
      assert reloaded.rejection_reason == "Unclear image"
    end

    test "requires rejection reason", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: ""}
      assert {:error, :reason_required} = RejectVerificationDocument.execute(params)
    end

    test "requires non-nil rejection reason", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: nil}
      assert {:error, :reason_required} = RejectVerificationDocument.execute(params)
    end

    test "fails for non-existent document", %{admin: admin} do
      params = %{document_id: Ecto.UUID.generate(), reviewer_id: admin.id, reason: "Invalid"}
      assert {:error, :not_found} = RejectVerificationDocument.execute(params)
    end

    test "fails for already rejected document", %{admin: admin, document: doc} do
      # First rejection
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: "First rejection"}
      assert {:ok, _rejected} = RejectVerificationDocument.execute(params)

      # Second rejection should fail
      params2 = %{document_id: doc.id, reviewer_id: admin.id, reason: "Second rejection"}
      assert {:error, :document_not_pending} = RejectVerificationDocument.execute(params2)
    end

    test "fails for already approved document", %{admin: admin, document: doc} do
      # First approve
      approve_params = %{document_id: doc.id, reviewer_id: admin.id}
      assert {:ok, _approved} = ApproveVerificationDocument.execute(approve_params)

      # Then try to reject should fail
      reject_params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Too late"}
      assert {:error, :document_not_pending} = RejectVerificationDocument.execute(reject_params)
    end

    test "dispatches :verification_document_rejected domain event", %{admin: admin, document: doc} do
      params = %{document_id: doc.id, reviewer_id: admin.id, reason: "Expired document"}
      assert {:ok, rejected} = RejectVerificationDocument.execute(params)

      event = assert_event_published(:verification_document_rejected)
      assert event.aggregate_id == doc.id
      assert event.payload.provider_id == rejected.provider_profile_id
      assert event.payload.reviewer_id == admin.id
    end
  end
end

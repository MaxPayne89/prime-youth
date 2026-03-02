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

    # Trigger: fixture creation publishes :user_registered integration events
    # Why: we only want to assert on events produced by the handler under test
    # Outcome: clean slate before each test runs
    clear_integration_events()

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

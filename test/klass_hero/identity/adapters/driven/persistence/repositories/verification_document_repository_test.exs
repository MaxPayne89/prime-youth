defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepositoryTest do
  @moduledoc """
  Tests for the VerificationDocumentRepository adapter.

  Follows TDD approach: tests written first, then implementation.
  """

  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository
  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Identity.Domain.Models.VerificationDocument

  describe "create/1" do
    test "persists verification document and returns domain entity" do
      {:ok, provider} = create_provider()

      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: provider.id,
          document_type: "business_registration",
          file_url: "verification-docs/test.pdf",
          original_filename: "registration.pdf"
        })

      assert {:ok, created} = VerificationDocumentRepository.create(doc)
      assert created.id == doc.id
      assert created.provider_profile_id == provider.id
      assert created.document_type == "business_registration"
      assert created.file_url == "verification-docs/test.pdf"
      assert created.original_filename == "registration.pdf"
      assert created.status == :pending
      assert %DateTime{} = created.inserted_at
    end

    test "returns error with invalid document type" do
      {:ok, provider} = create_provider()

      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: provider.id,
          document_type: "business_registration",
          file_url: "verification-docs/test.pdf",
          original_filename: "registration.pdf"
        })

      # Manually create a document with invalid type to test schema validation
      invalid_doc = %{doc | document_type: "invalid_type"}

      assert {:error, changeset} = VerificationDocumentRepository.create(invalid_doc)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "get/1" do
    test "retrieves existing verification document" do
      {:ok, provider} = create_provider()
      {:ok, created} = create_document(provider.id)

      assert {:ok, %VerificationDocument{} = retrieved} =
               VerificationDocumentRepository.get(created.id)

      assert retrieved.id == created.id
      assert retrieved.provider_profile_id == provider.id
      assert retrieved.document_type == "business_registration"
    end

    test "returns :not_found for non-existent document" do
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = VerificationDocumentRepository.get(non_existent_id)
    end
  end

  describe "get_by_provider/1" do
    test "retrieves all documents for a provider" do
      {:ok, provider} = create_provider()
      {:ok, _doc1} = create_document(provider.id, "business_registration")
      {:ok, _doc2} = create_document(provider.id, "insurance_certificate")

      assert {:ok, docs} = VerificationDocumentRepository.get_by_provider(provider.id)
      assert length(docs) == 2
      assert Enum.all?(docs, &(&1.provider_profile_id == provider.id))
    end

    test "returns empty list for provider with no documents" do
      {:ok, provider} = create_provider()

      assert {:ok, []} = VerificationDocumentRepository.get_by_provider(provider.id)
    end

    test "returns documents ordered by inserted_at descending" do
      {:ok, provider} = create_provider()

      {:ok, first_doc} = create_document(provider.id, "business_registration")
      # Small delay to ensure different timestamps
      Process.sleep(10)
      {:ok, second_doc} = create_document(provider.id, "insurance_certificate")

      assert {:ok, docs} = VerificationDocumentRepository.get_by_provider(provider.id)
      assert length(docs) == 2

      # Most recent first
      [newest, oldest] = docs
      assert newest.id == second_doc.id
      assert oldest.id == first_doc.id
    end
  end

  describe "update/1" do
    test "updates verification document status" do
      {:ok, provider} = create_provider()
      {:ok, created} = create_document(provider.id)
      reviewer = user_fixture(is_admin: true)

      # Approve the document using domain model
      {:ok, approved_doc} = VerificationDocument.approve(created, reviewer.id)

      assert {:ok, updated} = VerificationDocumentRepository.update(approved_doc)
      assert updated.status == :approved
      assert updated.reviewed_by_id == reviewer.id
      assert updated.reviewed_at != nil
    end

    test "updates document rejection with reason" do
      {:ok, provider} = create_provider()
      {:ok, created} = create_document(provider.id)
      reviewer = user_fixture(is_admin: true)

      {:ok, rejected_doc} =
        VerificationDocument.reject(created, reviewer.id, "Document is blurry")

      assert {:ok, updated} = VerificationDocumentRepository.update(rejected_doc)
      assert updated.status == :rejected
      assert updated.rejection_reason == "Document is blurry"
      assert updated.reviewed_by_id == reviewer.id
    end

    test "returns :not_found for non-existent document" do
      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: Ecto.UUID.generate(),
          document_type: "business_registration",
          file_url: "verification-docs/test.pdf",
          original_filename: "test.pdf"
        })

      assert {:error, :not_found} = VerificationDocumentRepository.update(doc)
    end
  end

  describe "list_pending/0" do
    test "returns all pending documents ordered by inserted_at ascending" do
      {:ok, provider1} = create_provider()
      {:ok, provider2} = create_provider()
      reviewer = user_fixture(is_admin: true)

      {:ok, pending1} = create_document(provider1.id)
      Process.sleep(10)
      {:ok, pending2} = create_document(provider2.id)

      # Approve one document to verify it's not included
      {:ok, approved} = VerificationDocument.approve(pending1, reviewer.id)
      {:ok, _} = VerificationDocumentRepository.update(approved)

      assert {:ok, docs} = VerificationDocumentRepository.list_pending()
      assert length(docs) == 1
      assert Enum.at(docs, 0).id == pending2.id
    end

    test "returns empty list when no pending documents exist" do
      assert {:ok, []} = VerificationDocumentRepository.list_pending()
    end
  end

  describe "list_by_status/1" do
    test "returns documents with specified status" do
      {:ok, provider} = create_provider()
      reviewer = user_fixture(is_admin: true)
      {:ok, doc1} = create_document(provider.id, "business_registration")
      {:ok, _doc2} = create_document(provider.id, "insurance_certificate")

      # Approve doc1
      {:ok, approved} = VerificationDocument.approve(doc1, reviewer.id)
      {:ok, _} = VerificationDocumentRepository.update(approved)

      assert {:ok, pending_docs} = VerificationDocumentRepository.list_by_status(:pending)
      assert length(pending_docs) == 1

      assert {:ok, approved_docs} = VerificationDocumentRepository.list_by_status(:approved)
      assert length(approved_docs) == 1
      assert Enum.at(approved_docs, 0).id == doc1.id
    end

    test "returns empty list for status with no documents" do
      assert {:ok, []} = VerificationDocumentRepository.list_by_status(:rejected)
    end
  end

  # Helper functions

  defp create_provider do
    ProviderProfileRepository.create_provider_profile(%{
      identity_id: Ecto.UUID.generate(),
      business_name: "Test Provider #{System.unique_integer()}"
    })
  end

  defp create_document(provider_id, type \\ "business_registration") do
    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: provider_id,
        document_type: type,
        file_url: "verification-docs/test-#{System.unique_integer()}.pdf",
        original_filename: "document.pdf"
      })

    VerificationDocumentRepository.create(doc)
  end
end

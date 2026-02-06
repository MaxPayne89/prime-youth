defmodule KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocumentTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Identity.Application.UseCases.Verification.SubmitVerificationDocument
  alias KlassHero.IdentityFixtures
  alias KlassHero.Shared.Adapters.Driven.Storage.StubStorageAdapter

  defmodule FailingStorageAdapter do
    @behaviour KlassHero.Shared.Domain.Ports.ForStoringFiles

    def upload(_bucket, _path, _binary, _opts), do: {:error, :upload_failed}
    def signed_url(_, _, _, _), do: {:error, :not_implemented}
    def delete(_, _, _), do: :ok
  end

  setup do
    name = :"stub_storage_#{System.unique_integer([:positive])}"
    {:ok, storage} = StubStorageAdapter.start_link(name: name)
    provider = IdentityFixtures.provider_profile_fixture()
    %{provider: provider, storage: storage}
  end

  describe "execute/1" do
    test "uploads document and creates record", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        file_binary: "pdf content here",
        original_filename: "registration.pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:ok, doc} = SubmitVerificationDocument.execute(params)
      assert doc.provider_profile_id == provider.id
      assert doc.document_type == "business_registration"
      assert doc.status == :pending
      assert doc.file_url =~ "verification-docs/providers/#{provider.id}"
    end

    test "stores file content in storage", %{provider: provider, storage: storage} do
      file_content = "test pdf binary content"

      params = %{
        provider_profile_id: provider.id,
        document_type: "insurance_certificate",
        file_binary: file_content,
        original_filename: "insurance.pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:ok, doc} = SubmitVerificationDocument.execute(params)

      # Verify file was stored in the stub adapter
      assert {:ok, ^file_content} =
               StubStorageAdapter.get_uploaded(:private, doc.file_url, agent: storage)
    end

    test "sanitizes filename to remove unsafe characters", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "id_document",
        file_binary: "content",
        original_filename: "my file (1).pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:ok, doc} = SubmitVerificationDocument.execute(params)
      # Parentheses and spaces should be replaced with underscores
      assert doc.file_url =~ "my_file__1_.pdf"
    end

    test "rejects invalid document type", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "invalid_type",
        file_binary: "content",
        original_filename: "doc.pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:error, errors} = SubmitVerificationDocument.execute(params)
      assert :document_type in Keyword.keys(errors)
    end

    test "accepts all valid document types", %{provider: provider, storage: storage} do
      valid_types =
        ~w(business_registration insurance_certificate id_document tax_certificate other)

      for doc_type <- valid_types do
        params = %{
          provider_profile_id: provider.id,
          document_type: doc_type,
          file_binary: "content for #{doc_type}",
          original_filename: "#{doc_type}.pdf",
          content_type: "application/pdf",
          storage_opts: [adapter: StubStorageAdapter, agent: storage]
        }

        assert {:ok, doc} = SubmitVerificationDocument.execute(params)
        assert doc.document_type == doc_type
      end
    end

    test "requires provider_profile_id", %{storage: storage} do
      params = %{
        document_type: "business_registration",
        file_binary: "content",
        original_filename: "doc.pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:error, errors} = SubmitVerificationDocument.execute(params)
      assert :provider_profile_id in Keyword.keys(errors)
    end

    test "requires file_binary", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        original_filename: "doc.pdf",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:error, errors} = SubmitVerificationDocument.execute(params)
      assert :file_binary in Keyword.keys(errors)
    end

    test "requires original_filename", %{provider: provider, storage: storage} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        file_binary: "content",
        content_type: "application/pdf",
        storage_opts: [adapter: StubStorageAdapter, agent: storage]
      }

      assert {:error, errors} = SubmitVerificationDocument.execute(params)
      assert :original_filename in Keyword.keys(errors)
    end

    test "returns error when storage upload fails", %{provider: provider} do
      params = %{
        provider_profile_id: provider.id,
        document_type: "business_registration",
        file_binary: "content",
        original_filename: "doc.pdf",
        storage_opts: [adapter: FailingStorageAdapter]
      }

      # Trigger: storage adapter returns {:error, :upload_failed}
      # Why: the with chain should propagate the storage error
      # Outcome: no document record created, error returned to caller
      assert {:error, :upload_failed} = SubmitVerificationDocument.execute(params)

      # Verify no document was persisted
      assert {:ok, []} = VerificationDocumentRepository.get_by_provider(provider.id)
    end
  end
end

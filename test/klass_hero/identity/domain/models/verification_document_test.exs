defmodule KlassHero.Identity.Domain.Models.VerificationDocumentTest do
  use ExUnit.Case, async: true

  alias KlassHero.Identity.Domain.Models.VerificationDocument

  describe "new/1" do
    test "creates valid verification document with pending status" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "business_registration",
        file_url: "verification-docs/providers/123/doc.pdf",
        original_filename: "registration.pdf"
      }

      assert {:ok, doc} = VerificationDocument.new(attrs)
      assert doc.status == :pending
      assert doc.document_type == "business_registration"
      assert doc.file_url == "verification-docs/providers/123/doc.pdf"
      assert doc.original_filename == "registration.pdf"
      assert doc.rejection_reason == nil
      assert doc.reviewed_by_id == nil
      assert doc.reviewed_at == nil
    end

    test "rejects invalid status" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "business_registration",
        file_url: "path",
        original_filename: "doc.pdf",
        status: :invalid
      }

      assert {:error, errors} = VerificationDocument.new(attrs)
      assert :status in Keyword.keys(errors)
    end

    test "rejects invalid document type" do
      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "invalid_type",
        file_url: "path",
        original_filename: "doc.pdf"
      }

      assert {:error, errors} = VerificationDocument.new(attrs)
      assert :document_type in Keyword.keys(errors)
    end

    test "rejects missing required fields" do
      attrs = %{
        id: Ecto.UUID.generate()
      }

      assert {:error, errors} = VerificationDocument.new(attrs)
      assert :provider_profile_id in Keyword.keys(errors)
      assert :document_type in Keyword.keys(errors)
      assert :file_url in Keyword.keys(errors)
      assert :original_filename in Keyword.keys(errors)
    end

    test "accepts all valid document types" do
      base_attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        file_url: "path",
        original_filename: "doc.pdf"
      }

      valid_types = [
        "business_registration",
        "insurance_certificate",
        "id_document",
        "tax_certificate",
        "other"
      ]

      for type <- valid_types do
        attrs = Map.put(base_attrs, :document_type, type)
        assert {:ok, doc} = VerificationDocument.new(attrs)
        assert doc.document_type == type
      end
    end
  end

  describe "approve/2" do
    test "sets status to approved with reviewer" do
      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: Ecto.UUID.generate(),
          document_type: "insurance_certificate",
          file_url: "path",
          original_filename: "doc.pdf"
        })

      reviewer_id = Ecto.UUID.generate()
      {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)

      assert approved.status == :approved
      assert approved.reviewed_by_id == reviewer_id
      assert approved.reviewed_at != nil
    end

    test "fails when document is not pending" do
      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: Ecto.UUID.generate(),
          document_type: "insurance_certificate",
          file_url: "path",
          original_filename: "doc.pdf"
        })

      reviewer_id = Ecto.UUID.generate()
      {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)

      # Trigger: trying to approve an already approved document
      # Why: documents can only transition from pending state
      # Outcome: returns error indicating document is not pending
      assert {:error, :document_not_pending} = VerificationDocument.approve(approved, reviewer_id)
    end
  end

  describe "reject/3" do
    test "sets status to rejected with reason" do
      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: Ecto.UUID.generate(),
          document_type: "insurance_certificate",
          file_url: "path",
          original_filename: "doc.pdf"
        })

      reviewer_id = Ecto.UUID.generate()
      {:ok, rejected} = VerificationDocument.reject(doc, reviewer_id, "Document expired")

      assert rejected.status == :rejected
      assert rejected.rejection_reason == "Document expired"
      assert rejected.reviewed_by_id == reviewer_id
      assert rejected.reviewed_at != nil
    end

    test "fails when document is not pending" do
      {:ok, doc} =
        VerificationDocument.new(%{
          id: Ecto.UUID.generate(),
          provider_profile_id: Ecto.UUID.generate(),
          document_type: "insurance_certificate",
          file_url: "path",
          original_filename: "doc.pdf"
        })

      reviewer_id = Ecto.UUID.generate()
      {:ok, rejected} = VerificationDocument.reject(doc, reviewer_id, "Expired")

      # Trigger: trying to reject an already rejected document
      # Why: documents can only transition from pending state
      # Outcome: returns error indicating document is not pending
      assert {:error, :document_not_pending} =
               VerificationDocument.reject(rejected, reviewer_id, "Another reason")
    end
  end

  describe "from_persistence/1" do
    test "reconstructs document from persistence data" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "business_registration",
        file_url: "path/to/file.pdf",
        original_filename: "doc.pdf",
        status: :approved,
        reviewed_by_id: Ecto.UUID.generate(),
        reviewed_at: now,
        rejection_reason: nil,
        inserted_at: now,
        updated_at: now
      }

      assert {:ok, doc} = VerificationDocument.from_persistence(attrs)
      assert doc.id == attrs.id
      assert doc.status == :approved
      assert doc.reviewed_by_id == attrs.reviewed_by_id
    end

    test "returns error for missing required keys" do
      attrs = %{
        id: Ecto.UUID.generate()
        # missing other required keys
      }

      assert {:error, :invalid_persistence_data} = VerificationDocument.from_persistence(attrs)
    end
  end
end

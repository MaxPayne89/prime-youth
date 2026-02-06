defmodule KlassHero.Identity.Adapters.Driven.Persistence.Mappers.VerificationDocumentMapperTest do
  @moduledoc """
  Tests for VerificationDocumentMapper, focusing on field translation and status conversion.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.VerificationDocumentMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema
  alias KlassHero.Identity.Domain.Models.VerificationDocument

  @provider_id Ecto.UUID.generate()
  @reviewer_id Ecto.UUID.generate()
  @now ~U[2025-01-15 10:30:00.000000Z]

  describe "to_domain/1" do
    test "converts schema to domain entity with correct field mapping" do
      schema = build_schema()
      domain = VerificationDocumentMapper.to_domain(schema)

      assert %VerificationDocument{} = domain
      assert is_binary(domain.id)
      # Trigger: DB uses provider_id, domain uses provider_profile_id
      # Why: semantic clarity — the domain cares about profile identity, not table name
      # Outcome: mapper translates between the two
      assert domain.provider_profile_id == to_string(@provider_id)
      assert domain.document_type == "business_registration"
      assert domain.file_url == "verification-docs/test.pdf"
      assert domain.original_filename == "registration.pdf"
      assert domain.status == :pending
      assert domain.rejection_reason == nil
      assert domain.reviewed_by_id == nil
      assert domain.reviewed_at == nil
    end

    test "converts nil status to :pending" do
      schema = build_schema(%{status: nil})
      domain = VerificationDocumentMapper.to_domain(schema)

      assert domain.status == :pending
    end

    test "converts all valid status strings to atoms" do
      for {status_string, expected_atom} <- [
            {"pending", :pending},
            {"approved", :approved},
            {"rejected", :rejected}
          ] do
        schema = build_schema(%{status: status_string})
        domain = VerificationDocumentMapper.to_domain(schema)

        assert domain.status == expected_atom
      end
    end

    test "raises on invalid status string" do
      schema = build_schema(%{status: "unknown_status"})

      assert_raise RuntimeError, ~r/verification document status/, fn ->
        VerificationDocumentMapper.to_domain(schema)
      end
    end

    test "maps reviewed fields when present" do
      schema =
        build_schema(%{
          status: "approved",
          reviewed_by_id: @reviewer_id,
          reviewed_at: @now
        })

      domain = VerificationDocumentMapper.to_domain(schema)

      assert domain.reviewed_by_id == to_string(@reviewer_id)
      assert domain.reviewed_at == @now
    end

    test "maps rejection reason when present" do
      schema =
        build_schema(%{
          status: "rejected",
          rejection_reason: "Document is expired",
          reviewed_by_id: @reviewer_id,
          reviewed_at: @now
        })

      domain = VerificationDocumentMapper.to_domain(schema)

      assert domain.rejection_reason == "Document is expired"
      assert domain.status == :rejected
    end
  end

  describe "to_schema/1" do
    test "converts domain entity to schema attrs with correct field mapping" do
      domain = %VerificationDocument{
        id: Ecto.UUID.generate(),
        provider_profile_id: Ecto.UUID.generate(),
        document_type: "insurance_certificate",
        file_url: "verification-docs/insurance.pdf",
        original_filename: "insurance.pdf",
        status: :pending
      }

      attrs = VerificationDocumentMapper.to_schema(domain)

      assert is_map(attrs)
      # Trigger: domain uses provider_profile_id, DB uses provider_id
      # Why: schema matches the database column name
      # Outcome: mapper translates back for persistence
      assert attrs.provider_id == domain.provider_profile_id
      assert attrs.document_type == "insurance_certificate"
      assert attrs.file_url == "verification-docs/insurance.pdf"
      assert attrs.original_filename == "insurance.pdf"
      assert attrs.status == "pending"
      assert attrs.id == domain.id
    end

    test "converts status atom to string" do
      for {status_atom, expected_string} <- [
            {:pending, "pending"},
            {:approved, "approved"},
            {:rejected, "rejected"}
          ] do
        domain = build_domain(%{status: status_atom})
        attrs = VerificationDocumentMapper.to_schema(domain)

        assert attrs.status == expected_string
      end
    end

    test "includes review fields when present" do
      domain =
        build_domain(%{
          status: :rejected,
          rejection_reason: "Unclear photo",
          reviewed_by_id: Ecto.UUID.generate(),
          reviewed_at: @now
        })

      attrs = VerificationDocumentMapper.to_schema(domain)

      assert attrs.rejection_reason == "Unclear photo"
      assert attrs.reviewed_by_id == domain.reviewed_by_id
      assert attrs.reviewed_at == @now
    end
  end

  describe "to_domain_list/1" do
    test "converts list of schemas to domain entities" do
      schemas = [build_schema(), build_schema(%{document_type: "id_document"})]
      domains = VerificationDocumentMapper.to_domain_list(schemas)

      assert length(domains) == 2
      assert Enum.all?(domains, &match?(%VerificationDocument{}, &1))
    end

    test "returns empty list for empty input" do
      assert [] == VerificationDocumentMapper.to_domain_list([])
    end
  end

  defp build_schema(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      provider_id: @provider_id,
      document_type: "business_registration",
      file_url: "verification-docs/test.pdf",
      original_filename: "registration.pdf",
      status: "pending",
      rejection_reason: nil,
      reviewed_by_id: nil,
      reviewed_at: nil,
      inserted_at: @now,
      updated_at: @now
    }

    struct(VerificationDocumentSchema, Map.merge(defaults, overrides))
  end

  defp build_domain(overrides) do
    defaults = %{
      id: Ecto.UUID.generate(),
      provider_profile_id: Ecto.UUID.generate(),
      document_type: "business_registration",
      file_url: "verification-docs/test.pdf",
      original_filename: "test.pdf",
      status: :pending,
      rejection_reason: nil,
      reviewed_by_id: nil,
      reviewed_at: nil
    }

    struct(VerificationDocument, Map.merge(defaults, overrides))
  end
end

defmodule KlassHero.ProviderFixtures do
  @moduledoc """
  Test helpers for creating entities in the Provider bounded context.
  """

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.VerificationDocumentRepository
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Provider.Domain.Models.VerificationDocument
  alias KlassHero.Repo

  @doc """
  Creates a provider profile for testing.

  Uses the schema directly to insert into database, then maps to domain model.
  """
  def provider_profile_fixture(attrs \\ %{}) do
    attrs_map = Map.new(attrs)

    # Trigger: identity_id references users table via FK
    # Why: consolidated migrations enforce referential integrity
    # Outcome: every provider profile is linked to a real user record
    identity_id =
      attrs_map[:identity_id] ||
        KlassHero.AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider]).id

    defaults = %{
      identity_id: identity_id,
      business_name: "Test Provider #{System.unique_integer([:positive])}"
    }

    merged = Map.merge(defaults, attrs_map)

    {:ok, schema} =
      %ProviderProfileSchema{}
      |> ProviderProfileSchema.changeset(merged)
      |> Repo.insert()

    ProviderProfileMapper.to_domain(schema)
  end

  @doc """
  Creates a staff member for testing.

  Uses the schema directly to insert into database, then maps to domain model.
  """
  def staff_member_fixture(attrs \\ %{}) do
    defaults = %{
      provider_id: attrs[:provider_id] || provider_profile_fixture().id,
      first_name: "Staff #{System.unique_integer([:positive])}",
      last_name: "Member"
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, schema} =
      %StaffMemberSchema{}
      |> StaffMemberSchema.create_changeset(merged)
      |> Repo.insert()

    StaffMemberMapper.to_domain(schema)
  end

  @doc """
  Creates a pending verification document for testing.

  Returns the unwrapped domain model (not {:ok, doc}).
  Accepts optional `provider_id`; if omitted, creates a new provider profile.
  """
  def verification_document_fixture(attrs \\ %{}) do
    attrs_map = Map.new(attrs)

    {:ok, doc} =
      VerificationDocument.new(%{
        id: Ecto.UUID.generate(),
        provider_profile_id: attrs_map[:provider_id] || provider_profile_fixture().id,
        document_type: attrs_map[:document_type] || "business_registration",
        file_url: attrs_map[:file_url] || "verification-docs/#{Ecto.UUID.generate()}.pdf",
        original_filename: attrs_map[:original_filename] || "doc.pdf"
      })

    {:ok, persisted} = VerificationDocumentRepository.create(doc)
    persisted
  end

  @doc """
  Creates an approved verification document for testing.

  Composes: pending -> approve -> persist.
  Requires `reviewer_id`. Accepts optional `provider_id`.
  """
  def approved_verification_document_fixture(attrs \\ %{}) do
    attrs_map = Map.new(attrs)
    reviewer_id = attrs_map[:reviewer_id] || raise "reviewer_id is required"

    doc = verification_document_fixture(attrs)
    {:ok, approved} = VerificationDocument.approve(doc, reviewer_id)
    {:ok, persisted} = VerificationDocumentRepository.update(approved)
    persisted
  end

  @doc """
  Creates a rejected verification document for testing.

  Composes: pending -> reject -> persist.
  Requires `reviewer_id`. Accepts optional `provider_id` and `rejection_reason`.
  """
  def rejected_verification_document_fixture(attrs \\ %{}) do
    attrs_map = Map.new(attrs)
    reviewer_id = attrs_map[:reviewer_id] || raise "reviewer_id is required"
    reason = attrs_map[:rejection_reason] || "Invalid document"

    doc = verification_document_fixture(attrs)
    {:ok, rejected} = VerificationDocument.reject(doc, reviewer_id, reason)
    {:ok, persisted} = VerificationDocumentRepository.update(rejected)
    persisted
  end
end

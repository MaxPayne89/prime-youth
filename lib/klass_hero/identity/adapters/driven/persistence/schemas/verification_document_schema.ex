defmodule KlassHero.Identity.Adapters.Driven.Persistence.Schemas.VerificationDocumentSchema do
  @moduledoc """
  Ecto schema for the verification_documents table.

  This is an infrastructure adapter that maps database records to Ecto structs.
  Use VerificationDocumentMapper to convert between VerificationDocumentSchema
  and domain VerificationDocument entities.

  ## Field Name Mapping

  The database uses `provider_id` to reference the `providers` table.
  The domain model uses `provider_profile_id` for semantic clarity.
  The mapper handles this translation.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Accounts.User
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "verification_documents" do
    field :document_type, :string
    field :file_url, :string
    field :original_filename, :string
    field :status, :string, default: "pending"
    field :rejection_reason, :string
    field :reviewed_at, :utc_datetime_usec

    # Trigger: Database column is named provider_id
    # Why: References the providers table (which stores ProviderProfiles)
    # Outcome: Mapper translates provider_id <-> provider_profile_id
    belongs_to :provider, ProviderProfileSchema

    belongs_to :reviewed_by, User

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:provider_id, :document_type, :file_url, :original_filename]
  @optional_fields [:status, :rejection_reason, :reviewed_by_id, :reviewed_at]

  @valid_statuses ["pending", "approved", "rejected"]
  @valid_document_types [
    "business_registration",
    "insurance_certificate",
    "id_document",
    "tax_certificate",
    "other"
  ]

  @doc """
  Creates a changeset for inserting or updating a verification document.

  Required fields:
  - provider_id (reference to providers table)
  - document_type (one of: business_registration, insurance_certificate, id_document, tax_certificate, other)
  - file_url (path to file in object storage)
  - original_filename (original name of uploaded file)

  Optional fields:
  - status (defaults to "pending", must be one of: pending, approved, rejected)
  - rejection_reason (only relevant when status is rejected)
  - reviewed_by_id (reference to users table)
  - reviewed_at (timestamp of review)
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:document_type, @valid_document_types)
    |> foreign_key_constraint(:provider_id)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  @doc """
  Creates a changeset for approving a document.

  Sets status to "approved" and records the reviewer information.
  """
  def approve_changeset(schema, reviewer_id) do
    schema
    |> change(%{
      status: "approved",
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now()
    })
  end

  @doc """
  Creates a changeset for rejecting a document.

  Sets status to "rejected" and records the reviewer information
  along with the rejection reason.
  """
  def reject_changeset(schema, reviewer_id, reason) do
    schema
    |> change(%{
      status: "rejected",
      rejection_reason: reason,
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now()
    })
  end
end

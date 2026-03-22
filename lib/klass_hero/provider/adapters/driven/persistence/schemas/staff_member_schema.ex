defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema do
  @moduledoc """
  Ecto schema for the staff_members table.

  Use StaffMemberMapper to convert between this schema and domain StaffMember entities.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Shared.Categories

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  schema "staff_members" do
    belongs_to :provider, ProviderProfileSchema, type: :binary_id
    field :first_name, :string
    field :last_name, :string
    field :role, :string
    field :email, :string
    field :bio, :string
    field :headshot_url, :string
    field :tags, {:array, :string}, default: []
    field :qualifications, {:array, :string}, default: []
    field :active, :boolean, default: true
    field :invitation_status, :string
    field :invitation_token_hash, :binary
    field :invitation_sent_at, :utc_datetime_usec
    belongs_to :user, KlassHero.Accounts.User, type: :binary_id

    timestamps()
  end

  @doc """
  Changeset for creating a new staff member.

  provider_id is set programmatically via put_change, not cast from user input.

  Validation constants intentionally mirror StaffMember domain model.
  Domain validates on write; Ecto validates at persistence boundary.
  Keep both in sync when changing constraints.
  """
  def create_changeset(schema, attrs) do
    provider_id = attrs[:provider_id] || attrs["provider_id"]

    schema
    |> cast(attrs, [
      :first_name,
      :last_name,
      :role,
      :email,
      :bio,
      :headshot_url,
      :tags,
      :qualifications,
      :active,
      :invitation_status,
      :invitation_token_hash
    ])
    |> put_change(:provider_id, provider_id)
    |> validate_required([:provider_id, :first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:headshot_url, max: 500)
    |> validate_tags()
    |> foreign_key_constraint(:provider_id)
  end

  @doc """
  Form changeset for editing staff members via LiveView.
  Excludes provider_id (set programmatically, immutable after creation).

  Validation constants intentionally mirror StaffMember domain model.
  Domain validates on write; Ecto validates at persistence boundary.
  Keep both in sync when changing constraints.
  """
  def edit_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :first_name,
      :last_name,
      :role,
      :email,
      :bio,
      :headshot_url,
      :tags,
      :qualifications,
      :active,
      :invitation_status,
      :invitation_token_hash,
      :invitation_sent_at,
      :user_id
    ])
    |> validate_required([:first_name, :last_name])
    |> validate_length(:first_name, min: 1, max: 100)
    |> validate_length(:last_name, min: 1, max: 100)
    |> validate_length(:role, max: 100)
    |> validate_length(:email, max: 255)
    |> validate_length(:bio, max: 2000)
    |> validate_length(:headshot_url, max: 500)
    |> validate_tags()
    |> validate_inclusion(:invitation_status, ~w(pending sent failed accepted expired))
  end

  @doc """
  Admin changeset for Backpex dashboard edits.

  Only allows toggling `active` status — all other fields are provider-owned.
  Accepts Backpex 3-arg signature (schema, attrs, metadata); metadata is unused
  since no audit trail fields are needed for active toggle.
  """
  def admin_changeset(schema, attrs, _metadata) do
    cast(schema, attrs, [:active])
  end

  @doc """
  Changeset for updating invitation-specific fields.

  Used by test fixtures to set invitation state after initial insert, and by
  any future code paths that need to update invitation fields independently
  of the general `edit_changeset`.
  """
  def invitation_changeset(staff_member, attrs) do
    staff_member
    |> cast(attrs, [:invitation_status, :invitation_token_hash, :invitation_sent_at, :user_id])
    |> validate_inclusion(:invitation_status, ~w(pending sent failed accepted expired))
  end

  defp validate_tags(changeset) do
    case get_change(changeset, :tags) do
      nil ->
        changeset

      tags ->
        valid = Categories.categories()
        invalid = Enum.reject(tags, &(&1 in valid))

        if invalid == [] do
          changeset
        else
          add_error(changeset, :tags, "contains invalid tags: #{Enum.join(invalid, ", ")}")
        end
    end
  end
end

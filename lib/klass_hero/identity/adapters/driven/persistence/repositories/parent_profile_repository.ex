defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ParentProfileRepository do
  @moduledoc """
  Repository implementation for storing and retrieving parent profiles from the database.

  Implements the ForStoringParentProfiles port with:
  - Domain entity mapping via ParentProfileMapper
  - Idiomatic "let it crash" error handling

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id
  - UNIQUE constraint on identity_id (prevents duplicate profiles)

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringParentProfiles

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ParentProfileMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ParentProfileSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers
  alias KlassHeroWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new parent profile in the database.

  Returns:
  - `{:ok, ParentProfile.t()}` on success
  - `{:error, :duplicate_resource}` - Parent profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  def create_parent_profile(attrs) when is_map(attrs) do
    schema_attrs = prepare_attrs_for_schema(attrs)

    %ParentProfileSchema{}
    |> ParentProfileSchema.changeset(schema_attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        {:ok, ParentProfileMapper.to_domain(schema)}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
          Logger.warning(
            "[Identity.ParentProfileRepository] Duplicate parent profile",
            error_id: ErrorIds.parent_duplicate_identity(),
            identity_id: attrs[:identity_id]
          )

          {:error, :duplicate_resource}
        else
          Logger.warning(
            "[Identity.ParentProfileRepository] Validation error creating parent profile",
            identity_id: attrs[:identity_id],
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
        end
    end
  end

  @impl true
  @doc """
  Retrieves a parent profile by identity ID from the database.

  Returns:
  - `{:ok, ParentProfile.t()}` when parent profile is found
  - `{:error, :not_found}` when no parent profile exists with the given identity_id
  """
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    case Repo.one(from p in ParentProfileSchema, where: p.identity_id == ^identity_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ParentProfileMapper.to_domain(schema)}
    end
  end

  @impl true
  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_profile?(identity_id) when is_binary(identity_id) do
    ParentProfileSchema
    |> where([p], p.identity_id == ^identity_id)
    |> Repo.exists?()
  end

  defp prepare_attrs_for_schema(attrs) do
    attrs
    |> maybe_convert_tier_to_string()
  end

  defp maybe_convert_tier_to_string(attrs) do
    case Map.get(attrs, :subscription_tier) do
      tier when is_atom(tier) and not is_nil(tier) ->
        Map.put(attrs, :subscription_tier, Atom.to_string(tier))

      _ ->
        attrs
    end
  end
end

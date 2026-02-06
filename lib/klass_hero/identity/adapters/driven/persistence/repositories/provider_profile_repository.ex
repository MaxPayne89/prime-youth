defmodule KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ProviderProfileRepository do
  @moduledoc """
  Repository implementation for storing and retrieving provider profiles from the database.

  Implements the ForStoringProviderProfiles port with:
  - Domain entity mapping via ProviderProfileMapper
  - Idiomatic "let it crash" error handling

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id and business_name
  - UNIQUE constraint on identity_id (prevents duplicate profiles)

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Identity.Domain.Ports.ForStoringProviderProfiles

  import Ecto.Query

  alias KlassHero.Identity.Adapters.Driven.Persistence.Mappers.ProviderProfileMapper
  alias KlassHero.Identity.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema
  alias KlassHero.Repo
  alias KlassHero.Shared.Adapters.Driven.Persistence.EctoErrorHelpers
  alias KlassHeroWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new provider profile in the database.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :duplicate_resource}` - Provider profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  def create_provider_profile(attrs) when is_map(attrs) do
    schema_attrs = prepare_attrs_for_schema(attrs)

    %ProviderProfileSchema{}
    |> ProviderProfileSchema.changeset(schema_attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        {:ok, ProviderProfileMapper.to_domain(schema)}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
          Logger.warning(
            "[Identity.ProviderProfileRepository] Duplicate provider profile",
            error_id: ErrorIds.provider_duplicate_identity(),
            identity_id: attrs[:identity_id]
          )

          {:error, :duplicate_resource}
        else
          Logger.warning(
            "[Identity.ProviderProfileRepository] Validation error creating provider profile",
            identity_id: attrs[:identity_id],
            errors: inspect(changeset.errors)
          )

          {:error, changeset}
        end
    end
  end

  @impl true
  @doc """
  Retrieves a provider profile by identity ID from the database.

  Returns:
  - `{:ok, ProviderProfile.t()}` when provider profile is found
  - `{:error, :not_found}` when no provider profile exists with the given identity_id
  """
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    case Repo.one(from p in ProviderProfileSchema, where: p.identity_id == ^identity_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ProviderProfileMapper.to_domain(schema)}
    end
  end

  @impl true
  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_profile?(identity_id) when is_binary(identity_id) do
    ProviderProfileSchema
    |> where([p], p.identity_id == ^identity_id)
    |> Repo.exists?()
  end

  @impl true
  @doc """
  Retrieves a provider profile by its ID.

  Returns:
  - `{:ok, ProviderProfile.t()}` when provider profile is found
  - `{:error, :not_found}` when no provider profile exists with the given ID
  """
  def get(id) when is_binary(id) do
    case Repo.get(ProviderProfileSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, ProviderProfileMapper.to_domain(schema)}
    end
  end

  @impl true
  @doc """
  Updates an existing provider profile in the database.

  Returns:
  - `{:ok, ProviderProfile.t()}` on success
  - `{:error, :not_found}` when provider profile doesn't exist
  - `{:error, changeset}` on validation failure
  """
  def update(provider_profile) do
    case Repo.get(ProviderProfileSchema, provider_profile.id) do
      nil ->
        {:error, :not_found}

      schema ->
        attrs = ProviderProfileMapper.to_schema(provider_profile)

        schema
        |> ProviderProfileSchema.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated} -> {:ok, ProviderProfileMapper.to_domain(updated)}
          {:error, changeset} -> {:error, changeset}
        end
    end
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

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
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  def create_provider_profile(attrs) when is_map(attrs) do
    Logger.info("[Identity.ProviderProfileRepository] Creating provider profile",
      identity_id: attrs[:identity_id],
      business_name: attrs[:business_name]
    )

    %ProviderProfileSchema{}
    |> ProviderProfileSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        provider_profile = ProviderProfileMapper.to_domain(schema)

        Logger.info(
          "[Identity.ProviderProfileRepository] Successfully created provider profile (ID: #{provider_profile.id}) for identity_id: #{provider_profile.identity_id}"
        )

        {:ok, provider_profile}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
          Logger.warning(
            "[Identity.ProviderProfileRepository] Duplicate provider profile",
            error_id: ErrorIds.provider_duplicate_identity(),
            identity_id: attrs[:identity_id]
          )

          {:error, :duplicate_identity}
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
    Logger.info(
      "[Identity.ProviderProfileRepository] Retrieving provider profile by identity_id: #{identity_id}"
    )

    case Repo.one(from p in ProviderProfileSchema, where: p.identity_id == ^identity_id) do
      nil ->
        Logger.info(
          "[Identity.ProviderProfileRepository] Provider profile not found for identity_id: #{identity_id}"
        )

        {:error, :not_found}

      schema ->
        provider_profile = ProviderProfileMapper.to_domain(schema)

        Logger.info(
          "[Identity.ProviderProfileRepository] Successfully retrieved provider profile (ID: #{provider_profile.id}) for identity_id: #{identity_id}"
        )

        {:ok, provider_profile}
    end
  end

  @impl true
  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_profile?(identity_id) when is_binary(identity_id) do
    Logger.info(
      "[Identity.ProviderProfileRepository] Checking if provider profile exists for identity_id: #{identity_id}"
    )

    exists =
      ProviderProfileSchema
      |> where([p], p.identity_id == ^identity_id)
      |> Repo.exists?()

    Logger.info(
      "[Identity.ProviderProfileRepository] Provider profile existence check for identity_id #{identity_id}: #{exists}"
    )

    exists
  end
end

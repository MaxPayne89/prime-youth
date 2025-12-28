defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository do
  @moduledoc """
  Repository implementation for storing and retrieving provider profiles from the database.

  Implements the ForStoringProviders port with:
  - Domain entity mapping via ProviderMapper
  - Idiomatic "let it crash" error handling

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id and business_name
  - UNIQUE constraint on identity_id (prevents duplicate profiles)

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
  """

  @behaviour PrimeYouth.Providing.Domain.Ports.ForStoringProviders

  import Ecto.Query

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Mappers.ProviderMapper
  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema
  alias PrimeYouth.Repo
  alias PrimeYouth.Shared.Adapters.Driven.Persistence.EctoErrorHelpers
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new provider profile in the database.

  Returns:
  - `{:ok, Provider.t()}` on success
  - `{:error, :duplicate_identity}` - Provider profile already exists for this identity_id
  - `{:error, changeset}` - Validation failure
  """
  def create_provider_profile(attrs) when is_map(attrs) do
    Logger.info("[ProviderRepository] Creating provider profile",
      identity_id: attrs[:identity_id],
      business_name: attrs[:business_name]
    )

    %ProviderSchema{}
    |> ProviderSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} ->
        provider = ProviderMapper.to_domain(schema)

        Logger.info(
          "[ProviderRepository] Successfully created provider profile (ID: #{provider.id}) for identity_id: #{provider.identity_id}"
        )

        {:ok, provider}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
          Logger.warning(
            "[ProviderRepository] Duplicate provider profile",
            error_id: ErrorIds.provider_duplicate_identity(),
            identity_id: attrs[:identity_id]
          )

          {:error, :duplicate_identity}
        else
          Logger.warning(
            "[ProviderRepository] Validation error creating provider profile",
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
  - `{:ok, Provider.t()}` when provider profile is found
  - `{:error, :not_found}` when no provider profile exists with the given identity_id
  """
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    Logger.info("[ProviderRepository] Retrieving provider profile by identity_id: #{identity_id}")

    case Repo.one(from p in ProviderSchema, where: p.identity_id == ^identity_id) do
      nil ->
        Logger.info(
          "[ProviderRepository] Provider profile not found for identity_id: #{identity_id}"
        )

        {:error, :not_found}

      schema ->
        provider = ProviderMapper.to_domain(schema)

        Logger.info(
          "[ProviderRepository] Successfully retrieved provider profile (ID: #{provider.id}) for identity_id: #{identity_id}"
        )

        {:ok, provider}
    end
  end

  @impl true
  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean directly.
  """
  def has_profile?(identity_id) when is_binary(identity_id) do
    Logger.info(
      "[ProviderRepository] Checking if provider profile exists for identity_id: #{identity_id}"
    )

    exists =
      ProviderSchema
      |> where([p], p.identity_id == ^identity_id)
      |> Repo.exists?()

    Logger.info(
      "[ProviderRepository] Provider profile existence check for identity_id #{identity_id}: #{exists}"
    )

    exists
  end
end

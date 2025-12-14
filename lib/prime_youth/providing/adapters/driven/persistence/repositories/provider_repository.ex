defmodule PrimeYouth.Providing.Adapters.Driven.Persistence.Repositories.ProviderRepository do
  @moduledoc """
  Repository implementation for storing and retrieving provider profiles from the database.

  Implements the ForStoringProviders port with:
  - Domain entity mapping via ProviderMapper
  - Comprehensive logging for database operations
  - Bidirectional conversion for create/read operations

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id and business_name
  - UNIQUE constraint on identity_id (prevents duplicate profiles)
  """

  @behaviour PrimeYouth.Providing.Domain.Ports.ForStoringProviders

  import Ecto.Query

  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Mappers.ProviderMapper
  alias PrimeYouth.Providing.Adapters.Driven.Persistence.Schemas.ProviderSchema
  alias PrimeYouth.Providing.Domain.Models.Provider
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new provider profile in the database.

  Accepts a map with provider attributes. The identity_id and business_name are required.
  All other fields are optional. Auto-generates UUID for id field if not provided.

  Returns:
  - {:ok, Provider.t()} on success
  - {:error, :duplicate_identity} - Provider profile already exists for this identity_id
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProviderRepository.create_provider_profile(%{identity_id: "550e8400-...", business_name: "My Business"})
      {:ok, %Provider{...}}

      iex> ProviderRepository.create_provider_profile(%{identity_id: "existing-id", business_name: "Another"})
      {:error, :duplicate_identity}
  """
  @spec create_provider_profile(map()) ::
          {:ok, Provider.t()}
          | {:error,
             :duplicate_identity
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def create_provider_profile(attrs) when is_map(attrs) do
    Logger.info("[ProviderRepository] Creating provider profile",
      identity_id: attrs[:identity_id],
      business_name: attrs[:business_name]
    )

    try do
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
          if duplicate_identity_error?(errors) do
            Logger.warning(
              "[ProviderRepository] Duplicate provider profile for identity_id: #{attrs[:identity_id]}"
            )

            {:error, :duplicate_identity}
          else
            Logger.error(
              "[ProviderRepository] Validation error creating provider profile",
              error_id: ErrorIds.provider_create_query_error(),
              identity_id: attrs[:identity_id],
              errors: inspect(changeset.errors)
            )

            {:error, :database_query_error}
          end
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProviderRepository] Database connection failed during provider profile creation",
          error_id: ErrorIds.provider_create_connection_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProviderRepository] Database query error during provider profile creation",
          error_id: ErrorIds.provider_create_query_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProviderRepository] Unexpected database error during provider profile creation",
          error_id: ErrorIds.provider_create_generic_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Retrieves a provider profile by identity ID from the database.

  Returns the provider profile associated with the given identity_id if found.

  Returns:
  - {:ok, Provider.t()} when provider profile is found
  - {:error, :not_found} when no provider profile exists with the given identity_id
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProviderRepository.get_by_identity_id("550e8400-e29b-41d4-a716-446655440001")
      {:ok, %Provider{identity_id: "550e8400-e29b-41d4-a716-446655440001", ...}}

      iex> ProviderRepository.get_by_identity_id("non-existent-id")
      {:error, :not_found}
  """
  @spec get_by_identity_id(String.t()) ::
          {:ok, Provider.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    Logger.info("[ProviderRepository] Retrieving provider profile by identity_id: #{identity_id}")

    query = from p in ProviderSchema, where: p.identity_id == ^identity_id

    try do
      case Repo.one(query) do
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
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProviderRepository] Database connection failed while fetching provider profile",
          error_id: ErrorIds.provider_get_connection_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProviderRepository] Database query error while fetching provider profile",
          error_id: ErrorIds.provider_get_query_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProviderRepository] Unexpected database error while fetching provider profile",
          error_id: ErrorIds.provider_get_generic_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Checks if a provider profile exists for the given identity ID.

  Returns boolean indicating whether a provider profile exists.

  Returns:
  - {:ok, true} when provider profile exists
  - {:ok, false} when no provider profile exists
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProviderRepository.has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, true}

      iex> ProviderRepository.has_profile?("non-existent-id")
      {:ok, false}
  """
  @spec has_profile?(String.t()) ::
          {:ok, boolean()}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def has_profile?(identity_id) when is_binary(identity_id) do
    Logger.info(
      "[ProviderRepository] Checking if provider profile exists for identity_id: #{identity_id}"
    )

    query =
      from p in ProviderSchema,
        where: p.identity_id == ^identity_id,
        select: count(p.id)

    try do
      count = Repo.one!(query)
      exists = count > 0

      Logger.info(
        "[ProviderRepository] Provider profile existence check for identity_id #{identity_id}: #{exists}"
      )

      {:ok, exists}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProviderRepository] Database connection failed during profile existence check",
          error_id: ErrorIds.provider_exists_connection_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProviderRepository] Database query error during profile existence check",
          error_id: ErrorIds.provider_exists_query_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProviderRepository] Unexpected database error during profile existence check",
          error_id: ErrorIds.provider_exists_generic_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  # Private helper to detect duplicate identity constraint violation
  defp duplicate_identity_error?(errors) do
    Enum.any?(errors, fn {field, {_message, opts}} ->
      field == :identity_id and Keyword.get(opts, :constraint) == :unique
    end)
  end
end

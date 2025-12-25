defmodule PrimeYouth.Parenting.Adapters.Driven.Persistence.Repositories.ParentRepository do
  @moduledoc """
  Repository implementation for storing and retrieving parent profiles from the database.

  Implements the ForStoringParents port with:
  - Domain entity mapping via ParentMapper
  - Comprehensive logging for database operations
  - Bidirectional conversion for create/read operations

  Data integrity is enforced at the database level through:
  - NOT NULL constraint on identity_id
  - UNIQUE constraint on identity_id (prevents duplicate profiles)

  ## Error Handling

  Translates Ecto/database errors to domain error atoms:
  - `Ecto.Changeset` (unique constraint on identity_id) → `:duplicate_identity`
  - `DBConnection.ConnectionError` → `:database_connection_error`
  - `Postgrex.Error` → `:database_query_error`
  - `Ecto.Query.CastError` → `:database_query_error`
  - Other errors → `:database_unavailable`

  All errors logged with unique ErrorIds for production monitoring.
  """

  @behaviour PrimeYouth.Parenting.Domain.Ports.ForStoringParents

  import Ecto.Query

  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Mappers.ParentMapper
  alias PrimeYouth.Parenting.Adapters.Driven.Persistence.Schemas.ParentSchema
  alias PrimeYouth.Parenting.Domain.Models.Parent
  alias PrimeYouth.Repo
  alias PrimeYouth.Shared.Adapters.Driven.Persistence.EctoErrorHelpers
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Creates a new parent profile in the database.

  Accepts a map with parent attributes. The identity_id is required.
  All other fields are optional. Auto-generates UUID for id field if not provided.

  Returns:
  - {:ok, Parent.t()} on success
  - {:error, :duplicate_identity} - Parent profile already exists for this identity_id
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ParentRepository.create_parent_profile(%{identity_id: "550e8400-..."})
      {:ok, %Parent{...}}

      iex> ParentRepository.create_parent_profile(%{identity_id: "existing-id"})
      {:error, :duplicate_identity}
  """
  @spec create_parent_profile(map()) ::
          {:ok, Parent.t()}
          | {:error,
             :duplicate_identity
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def create_parent_profile(attrs) when is_map(attrs) do
    Logger.info("[ParentRepository] Creating parent profile",
      identity_id: attrs[:identity_id]
    )

    try do
      %ParentSchema{}
      |> ParentSchema.changeset(attrs)
      |> Repo.insert()
      |> case do
        {:ok, schema} ->
          parent = ParentMapper.to_domain(schema)

          Logger.info(
            "[ParentRepository] Successfully created parent profile (ID: #{parent.id}) for identity_id: #{parent.identity_id}"
          )

          {:ok, parent}

        {:error, %Ecto.Changeset{errors: errors} = changeset} ->
          if EctoErrorHelpers.unique_constraint_violation?(errors, :identity_id) do
            Logger.warning(
              "[ParentRepository] Duplicate parent profile for identity_id: #{attrs[:identity_id]}"
            )

            {:error, :duplicate_identity}
          else
            Logger.error(
              "[ParentRepository] Validation error creating parent profile",
              error_id: ErrorIds.parent_create_query_error(),
              identity_id: attrs[:identity_id],
              errors: inspect(changeset.errors)
            )

            {:error, :database_query_error}
          end
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ParentRepository] Database connection failed during parent profile creation",
          error_id: ErrorIds.parent_create_connection_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ParentRepository] Database query error during parent profile creation",
          error_id: ErrorIds.parent_create_query_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ParentRepository] Unexpected database error during parent profile creation",
          error_id: ErrorIds.parent_create_generic_error(),
          identity_id: attrs[:identity_id],
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Retrieves a parent profile by identity ID from the database.

  Returns the parent profile associated with the given identity_id if found.

  Returns:
  - {:ok, Parent.t()} when parent profile is found
  - {:error, :not_found} when no parent profile exists with the given identity_id
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ParentRepository.get_by_identity_id("550e8400-e29b-41d4-a716-446655440001")
      {:ok, %Parent{identity_id: "550e8400-e29b-41d4-a716-446655440001", ...}}

      iex> ParentRepository.get_by_identity_id("non-existent-id")
      {:error, :not_found}
  """
  @spec get_by_identity_id(String.t()) ::
          {:ok, Parent.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_by_identity_id(identity_id) when is_binary(identity_id) do
    Logger.info("[ParentRepository] Retrieving parent profile by identity_id: #{identity_id}")

    query = from p in ParentSchema, where: p.identity_id == ^identity_id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info(
            "[ParentRepository] Parent profile not found for identity_id: #{identity_id}"
          )

          {:error, :not_found}

        schema ->
          parent = ParentMapper.to_domain(schema)

          Logger.info(
            "[ParentRepository] Successfully retrieved parent profile (ID: #{parent.id}) for identity_id: #{identity_id}"
          )

          {:ok, parent}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ParentRepository] Database connection failed while fetching parent profile",
          error_id: ErrorIds.parent_get_connection_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ParentRepository] Database query error while fetching parent profile",
          error_id: ErrorIds.parent_get_query_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ParentRepository] Unexpected database error while fetching parent profile",
          error_id: ErrorIds.parent_get_generic_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Checks if a parent profile exists for the given identity ID.

  Returns boolean indicating whether a parent profile exists.

  Returns:
  - {:ok, true} when parent profile exists
  - {:ok, false} when no parent profile exists
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ParentRepository.has_profile?("550e8400-e29b-41d4-a716-446655440001")
      {:ok, true}

      iex> ParentRepository.has_profile?("non-existent-id")
      {:ok, false}
  """
  @spec has_profile?(String.t()) ::
          {:ok, boolean()}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def has_profile?(identity_id) when is_binary(identity_id) do
    Logger.info(
      "[ParentRepository] Checking if parent profile exists for identity_id: #{identity_id}"
    )

    query =
      from p in ParentSchema,
        where: p.identity_id == ^identity_id,
        select: count(p.id)

    try do
      count = Repo.one!(query)
      exists = count > 0

      Logger.info(
        "[ParentRepository] Parent profile existence check for identity_id #{identity_id}: #{exists}"
      )

      {:ok, exists}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ParentRepository] Database connection failed during profile existence check",
          error_id: ErrorIds.parent_exists_connection_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ParentRepository] Database query error during profile existence check",
          error_id: ErrorIds.parent_exists_query_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ParentRepository] Unexpected database error during profile existence check",
          error_id: ErrorIds.parent_exists_generic_error(),
          identity_id: identity_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end
end

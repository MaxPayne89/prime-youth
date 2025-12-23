defmodule PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository do
  @moduledoc """
  Repository implementation for child persistence.

  Implements the ForStoringChildren port with comprehensive error handling,
  structured logging, and database interaction patterns.

  ## Operations

  - `get_by_id/1` - Retrieve a child by unique identifier
  - `create/1` - Create a new child record
  - `list_by_parent/1` - List all children for a parent (ordered alphabetically)

  ## Error Handling

  All operations follow a consistent error categorization pattern:
  - `:database_connection_error` - Network/connection issues
  - `:database_query_error` - Query execution failures
  - `:database_unavailable` - Generic database failures
  - `:not_found` - Child not found (get_by_id only)

  ## Logging

  All operations log with `[ChildRepository]` prefix for easy filtering.
  Error logs include error IDs from ErrorIds module for tracking.
  """

  @behaviour PrimeYouth.Family.Domain.Ports.ForStoringChildren

  import Ecto.Query

  alias PrimeYouth.Family.Adapters.Driven.Persistence.Mappers.ChildMapper
  alias PrimeYouth.Family.Adapters.Driven.Persistence.Schemas.ChildSchema
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  def get_by_id(child_id) when is_binary(child_id) do
    Logger.info(
      "[ChildRepository] Fetching child by ID",
      child_id: child_id
    )

    try do
      case Repo.get(ChildSchema, child_id) do
        nil ->
          Logger.info(
            "[ChildRepository] Child not found",
            child_id: child_id
          )

          {:error, :not_found}

        schema ->
          child = ChildMapper.to_domain(schema)

          Logger.info(
            "[ChildRepository] Successfully retrieved child",
            child_id: child.id,
            parent_id: child.parent_id
          )

          {:ok, child}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ChildRepository] Database connection failed during get_by_id",
          error_id: ErrorIds.child_get_connection_error(),
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      _error in [Ecto.Query.CastError] ->
        Logger.info(
          "[ChildRepository] Invalid UUID format during get_by_id",
          child_id: child_id
        )

        {:error, :not_found}

      error in [Postgrex.Error] ->
        Logger.error(
          "[ChildRepository] Database query error during get_by_id",
          error_id: ErrorIds.child_get_query_error(),
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ChildRepository] Unexpected database error during get_by_id",
          error_id: ErrorIds.child_get_generic_error(),
          child_id: child_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def create(attrs) when is_map(attrs) do
    Logger.info(
      "[ChildRepository] Creating child",
      parent_id: attrs[:parent_id],
      first_name: attrs[:first_name],
      last_name: attrs[:last_name]
    )

    changeset = ChildSchema.changeset(%ChildSchema{}, attrs)

    try do
      case Repo.insert(changeset) do
        {:ok, schema} ->
          child = ChildMapper.to_domain(schema)

          Logger.info(
            "[ChildRepository] Successfully created child",
            child_id: child.id,
            parent_id: child.parent_id,
            first_name: child.first_name,
            last_name: child.last_name
          )

          {:ok, child}

        {:error, changeset} ->
          Logger.warning(
            "[ChildRepository] Changeset validation failed during create",
            error_id: ErrorIds.child_create_query_error(),
            errors: changeset.errors
          )

          {:error, :database_query_error}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ChildRepository] Database connection failed during create",
          error_id: ErrorIds.child_create_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ChildRepository] Database query error during create",
          error_id: ErrorIds.child_create_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ChildRepository] Unexpected database error during create",
          error_id: ErrorIds.child_create_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_by_parent(parent_id) when is_binary(parent_id) do
    Logger.info(
      "[ChildRepository] Listing children by parent",
      parent_id: parent_id
    )

    query =
      from c in ChildSchema,
        where: c.parent_id == ^parent_id,
        order_by: [asc: c.first_name, asc: c.last_name]

    try do
      schemas = Repo.all(query)
      children = ChildMapper.to_domain_list(schemas)

      Logger.info(
        "[ChildRepository] Successfully listed children",
        parent_id: parent_id,
        count: length(children)
      )

      {:ok, children}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ChildRepository] Database connection failed during list_by_parent",
          error_id: ErrorIds.child_list_connection_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ChildRepository] Database query error during list_by_parent",
          error_id: ErrorIds.child_list_query_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ChildRepository] Unexpected database error during list_by_parent",
          error_id: ErrorIds.child_list_generic_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end
end

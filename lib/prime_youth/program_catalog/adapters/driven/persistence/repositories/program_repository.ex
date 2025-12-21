defmodule PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository do
  @moduledoc """
  Repository implementation for listing programs from the database.

  Implements the ForListingPrograms port with:
  - Domain entity mapping via ProgramMapper
  - Comprehensive logging for database operations

  Data integrity is enforced at the database level through NOT NULL constraints.
  """

  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ForListingPrograms
  @behaviour PrimeYouth.ProgramCatalog.Domain.Ports.ForUpdatingPrograms

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Mappers.ProgramMapper
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Queries.ProgramQueries
  alias PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
  alias PrimeYouth.ProgramCatalog.Domain.Models.Program
  alias PrimeYouth.Repo
  alias PrimeYouth.Shared.Domain.Types.Pagination.PageResult
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  @doc """
  Lists all programs from the database.

  Programs are ordered by title in ascending order for consistent display.
  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields (title, description, schedule, age_range, price, pricing_period).

  Returns:
  - {:ok, [Program.t()]} on success (empty list if no programs exist)
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProgramRepository.list_all_programs()
      {:ok, [%Program{title: "Art Adventures", ...}, %Program{title: "Soccer Camp", ...}]}

      iex> ProgramRepository.list_all_programs()
      {:ok, []}  # No programs in database

      iex> ProgramRepository.list_all_programs()
      {:error, :database_connection_error}  # Database connection failed

      iex> ProgramRepository.list_all_programs()
      {:error, :database_query_error}  # SQL syntax error

  """
  @spec list_all_programs() ::
          {:ok, [Program.t()]}
          | {:error, :database_connection_error | :database_query_error | :database_unavailable}
  def list_all_programs do
    Logger.info("[ProgramRepository] Starting list_all_programs query")

    query = from p in ProgramSchema, order_by: [asc: p.title]

    try do
      schemas = Repo.all(query)
      programs = ProgramMapper.to_domain_list(schemas)

      Logger.info(
        "[ProgramRepository] Successfully retrieved #{length(programs)} programs from database"
      )

      {:ok, programs}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed",
          error_id: ErrorIds.program_list_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProgramRepository] Database query error",
          error_id: ErrorIds.program_list_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error",
          error_id: ErrorIds.program_list_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Retrieves a single program by its unique ID (UUID) from the database.

  Data integrity is enforced at the database level through NOT NULL constraints
  on all required fields.

  Returns:
  - {:ok, Program.t()} when program is found
  - {:error, :not_found} when no program exists with the given ID
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      iex> ProgramRepository.get_by_id("550e8400-e29b-41d4-a716-446655440001")
      {:ok, %Program{id: "550e8400-e29b-41d4-a716-446655440001", title: "Art Adventures", ...}}

      iex> ProgramRepository.get_by_id("550e8400-e29b-41d4-a716-446655440099")
      {:error, :not_found}

      iex> ProgramRepository.get_by_id("invalid-uuid")
      {:error, :database_query_error}  # Invalid UUID format

  """
  @spec get_by_id(String.t()) ::
          {:ok, Program.t()}
          | {:error,
             :not_found
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def get_by_id(id) when is_binary(id) do
    Logger.info("[ProgramRepository] Starting get_by_id query for program ID: #{id}")

    query = from p in ProgramSchema, where: p.id == ^id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info("[ProgramRepository] Program not found with ID: #{id}")
          {:error, :not_found}

        schema ->
          program = ProgramMapper.to_domain(schema)

          Logger.info(
            "[ProgramRepository] Successfully retrieved program '#{program.title}' (ID: #{id}) from database"
          )

          {:ok, program}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProgramRepository] Database query error while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error while fetching program ID: #{id}",
          error_id: ErrorIds.program_get_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Lists programs with cursor-based pagination.

  Uses seek pagination (cursor-based) for efficient pagination of large result sets.
  Programs are ordered by creation time (newest first) using (inserted_at DESC, id DESC).

  Parameters:
  - `limit` - Number of items per page (1-100, silently constrained if out of range)
  - `cursor` - Base64-encoded cursor for pagination, nil for first page

  Returns:
  - {:ok, PageResult.t()} - Page of programs with pagination metadata
  - {:error, :invalid_cursor} - Cursor decoding/validation failure
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or constraint violation
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      # First page
      iex> ProgramRepository.list_programs_paginated(20, nil)
      {:ok, %PageResult{items: [...], next_cursor: "...", has_more: true}}

      # Subsequent page
      iex> ProgramRepository.list_programs_paginated(20, cursor)
      {:ok, %PageResult{items: [...], next_cursor: nil, has_more: false}}
  """
  @spec list_programs_paginated(pos_integer(), String.t() | nil) ::
          {:ok, PageResult.t()}
          | {:error,
             :invalid_cursor
             | :database_connection_error
             | :database_query_error
             | :database_unavailable}
  def list_programs_paginated(limit, cursor) do
    Logger.info(
      "[ProgramRepository] Starting list_programs_paginated query",
      limit: limit,
      has_cursor: !is_nil(cursor)
    )

    with {:ok, validated_limit} <- validate_limit(limit),
         {:ok, cursor_data} <- decode_cursor(cursor),
         {:ok, schemas} <- fetch_page(validated_limit, cursor_data) do
      {items, has_more} =
        if length(schemas) > validated_limit do
          {Enum.take(schemas, validated_limit), true}
        else
          {schemas, false}
        end

      next_cursor =
        if has_more do
          items |> List.last() |> encode_cursor()
        end

      domain_programs = Enum.map(items, &ProgramMapper.to_domain/1)
      page_result = PageResult.new(domain_programs, next_cursor, has_more)

      Logger.info(
        "[ProgramRepository] Successfully retrieved paginated programs",
        returned_count: length(domain_programs),
        has_more: has_more
      )

      {:ok, page_result}
    else
      {:error, :invalid_cursor} = error ->
        Logger.warning(
          "[ProgramRepository] Invalid pagination cursor",
          error_id: ErrorIds.program_pagination_invalid_cursor(),
          cursor: cursor
        )

        error

      {:error, reason} ->
        Logger.error(
          "[ProgramRepository] Failed to list programs (paginated)",
          error_id: ErrorIds.program_pagination_error(),
          reason: reason
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  @doc """
  Updates an existing program with optimistic locking.

  Uses the program's ID to fetch the current record from the database,
  applies the updates via an update changeset with optimistic locking,
  and returns the updated domain entity.

  The lock_version field is automatically incremented on successful update.
  If the program was modified by another process since it was loaded,
  the update fails with Ecto.StaleEntryError and returns {:error, :stale_data}.

  Parameters:
  - `program` - Domain Program entity with updated fields

  Returns:
  - {:ok, Program.t()} - Successfully updated program
  - {:error, :stale_data} - Optimistic lock conflict
  - {:error, :not_found} - Program ID does not exist
  - {:error, :constraint_violation} - Database constraint violation
  - {:error, :database_connection_error} - Connection/network failure
  - {:error, :database_query_error} - SQL error or schema mismatch
  - {:error, :database_unavailable} - Unexpected error

  ## Examples

      program = %Program{id: "uuid", title: "Updated Title", ...}
      {:ok, updated} = ProgramRepository.update(program)

      {:error, :stale_data} = ProgramRepository.update(stale_program)
      {:error, :not_found} = ProgramRepository.update(non_existent_program)
  """
  def update(%Program{} = program) do
    Logger.info(
      "[ProgramRepository] Starting update operation for program",
      program_id: program.id,
      title: program.title
    )

    try do
      # Verify program exists before attempting update
      if !Repo.get(ProgramSchema, program.id) do
        Logger.info(
          "[ProgramRepository] Program not found during update",
          program_id: program.id
        )

        throw({:error, :not_found})
      end

      # Fetch the current schema from database to get all current values
      # This preserves fields that aren't being updated
      current_schema = Repo.get!(ProgramSchema, program.id)

      # Build a schema with the original lock_version from the domain model
      # This is what the client saw when they loaded the program
      schema_with_client_version = %{current_schema | lock_version: program.lock_version || 1}

      # Convert domain Program to update attributes
      attrs = ProgramMapper.to_schema(program)

      # Build update changeset with optimistic locking
      # Ecto will check if current_schema.lock_version matches what's in the DB
      changeset = ProgramSchema.update_changeset(schema_with_client_version, attrs)

      # Execute update
      case Repo.update(changeset) do
        {:ok, updated_schema} ->
          updated_program = ProgramMapper.to_domain(updated_schema)

          Logger.info(
            "[ProgramRepository] Successfully updated program",
            program_id: program.id,
            title: updated_program.title,
            lock_version: updated_schema.lock_version
          )

          {:ok, updated_program}

        {:error, changeset} ->
          Logger.warning(
            "[ProgramRepository] Program update failed due to changeset errors",
            error_id: ErrorIds.program_update_query_error(),
            program_id: program.id,
            errors: changeset.errors
          )

          {:error, :database_query_error}
      end
    rescue
      error in [Ecto.StaleEntryError] ->
        Logger.warning(
          "[ProgramRepository] Optimistic lock conflict during program update",
          error_id: ErrorIds.program_update_stale_entry_error(),
          program_id: program.id,
          error_type: error.__struct__
        )

        {:error, :stale_data}

      error in [Ecto.ConstraintError] ->
        Logger.error(
          "[ProgramRepository] Constraint violation during program update",
          error_id: ErrorIds.program_update_constraint_violation(),
          program_id: program.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :constraint_violation}

      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed during program update",
          error_id: ErrorIds.program_update_connection_error(),
          program_id: program.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error] ->
        Logger.error(
          "[ProgramRepository] Database query error during program update",
          error_id: ErrorIds.program_update_query_error(),
          program_id: program.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error during program update",
          error_id: ErrorIds.program_update_generic_error(),
          program_id: program.id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp validate_limit(limit) when is_integer(limit) and limit >= 1 and limit <= 100 do
    {:ok, limit}
  end

  defp validate_limit(limit) when is_integer(limit) and limit < 1 do
    {:ok, 1}
  end

  defp validate_limit(limit) when is_integer(limit) and limit > 100 do
    {:ok, 100}
  end

  defp validate_limit(_), do: {:ok, 20}

  defp decode_cursor(nil), do: {:ok, nil}

  defp decode_cursor(cursor) when is_binary(cursor) do
    with {:ok, decoded} <- Base.url_decode64(cursor, padding: false),
         {:ok, data} <- Jason.decode(decoded),
         {:ok, datetime} <- parse_cursor_timestamp(data["ts"]),
         {:ok, uuid} <- parse_cursor_uuid(data["id"]) do
      {:ok, {datetime, uuid}}
    else
      _ -> {:error, :invalid_cursor}
    end
  end

  defp parse_cursor_timestamp(ts) when is_integer(ts) do
    case DateTime.from_unix(ts, :microsecond) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _} -> {:error, :invalid_timestamp}
    end
  end

  defp parse_cursor_timestamp(_), do: {:error, :invalid_timestamp}

  defp parse_cursor_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp parse_cursor_uuid(_), do: {:error, :invalid_uuid}

  defp encode_cursor(program_schema) do
    cursor_data = %{
      "ts" => DateTime.to_unix(program_schema.inserted_at, :microsecond),
      "id" => program_schema.id
    }

    cursor_data
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp fetch_page(limit, cursor_data) do
    query =
      ProgramQueries.base_query()
      |> apply_cursor_filter(cursor_data)
      |> ProgramQueries.order_by_creation(:desc)
      |> ProgramQueries.limit_results(limit + 1)

    try do
      schemas = Repo.all(query)
      {:ok, schemas}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[ProgramRepository] Database connection failed during pagination",
          error_id: ErrorIds.program_pagination_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[ProgramRepository] Database query error during pagination",
          error_id: ErrorIds.program_pagination_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[ProgramRepository] Unexpected database error during pagination",
          error_id: ErrorIds.program_pagination_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  defp apply_cursor_filter(query, nil), do: query

  defp apply_cursor_filter(query, {cursor_ts, cursor_id}) do
    ProgramQueries.paginate_after_cursor(query, {cursor_ts, cursor_id}, :desc)
  end
end

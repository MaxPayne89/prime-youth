defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository do
  @moduledoc """
  Repository implementation for attendance record persistence.

  Implements ForManagingAttendance port with:
  - Optimistic locking for concurrent update protection
  - Comprehensive error handling

  ## Error Handling

  Translates Ecto/database errors to domain error atoms:
  - `Ecto.StaleEntryError` → `:stale_data` (optimistic locking conflict)
  - `DBConnection.ConnectionError` → `:database_connection_error`
  - `Postgrex.Error` → `:database_query_error`
  - `Ecto.ConstraintError` → `:constraint_violation` or specific constraint errors
  - Other errors → `:database_unavailable`

  All errors logged with unique ErrorIds for production monitoring.
  """

  @behaviour PrimeYouth.Attendance.Domain.Ports.ForManagingAttendance

  import Ecto.Query

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Mappers.AttendanceRecordMapper
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.AttendanceRecordSchema
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Attendance.Domain.Models.AttendanceRecord
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  def create(%AttendanceRecord{} = record) do
    Logger.info(
      "[AttendanceRepository] Creating attendance record",
      session_id: record.session_id,
      child_id: record.child_id
    )

    attrs = AttendanceRecordMapper.to_schema(record)
    changeset = AttendanceRecordSchema.changeset(%AttendanceRecordSchema{}, attrs)

    try do
      case Repo.insert(changeset) do
        {:ok, schema} ->
          created_record = AttendanceRecordMapper.to_domain(schema)

          Logger.info(
            "[AttendanceRepository] Successfully created attendance record",
            record_id: created_record.id,
            session_id: created_record.session_id,
            child_id: created_record.child_id
          )

          {:ok, created_record}

        {:error, changeset} ->
          handle_changeset_error(changeset, "create")
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during create",
          error_id: ErrorIds.attendance_create_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during create",
          error_id: ErrorIds.attendance_create_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during create",
          error_id: ErrorIds.attendance_create_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_by_session_and_child(session_id, child_id)
      when is_binary(session_id) and is_binary(child_id) do
    Logger.info(
      "[AttendanceRepository] Fetching attendance record by session and child",
      session_id: session_id,
      child_id: child_id
    )

    query =
      from a in AttendanceRecordSchema,
        where: a.session_id == ^session_id and a.child_id == ^child_id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info(
            "[AttendanceRepository] Attendance record not found",
            session_id: session_id,
            child_id: child_id
          )

          {:error, :not_found}

        schema ->
          record = AttendanceRecordMapper.to_domain(schema)

          Logger.info(
            "[AttendanceRepository] Successfully retrieved attendance record",
            record_id: record.id,
            session_id: record.session_id,
            child_id: record.child_id
          )

          {:ok, record}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during get_by_session_and_child",
          error_id: ErrorIds.attendance_get_connection_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during get_by_session_and_child",
          error_id: ErrorIds.attendance_get_query_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during get_by_session_and_child",
          error_id: ErrorIds.attendance_get_generic_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def get_by_id(record_id) when is_binary(record_id) do
    Logger.info("[AttendanceRepository] Fetching attendance record by ID", record_id: record_id)

    query = from a in AttendanceRecordSchema, where: a.id == ^record_id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info("[AttendanceRepository] Attendance record not found", record_id: record_id)
          {:error, :not_found}

        schema ->
          record = AttendanceRecordMapper.to_domain(schema)

          Logger.info(
            "[AttendanceRepository] Successfully retrieved attendance record",
            record_id: record.id,
            session_id: record.session_id,
            child_id: record.child_id
          )

          {:ok, record}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during get_by_id",
          error_id: ErrorIds.attendance_get_connection_error(),
          record_id: record_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during get_by_id",
          error_id: ErrorIds.attendance_get_query_error(),
          record_id: record_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during get_by_id",
          error_id: ErrorIds.attendance_get_generic_error(),
          record_id: record_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def get_many_by_ids(record_ids) when is_list(record_ids) do
    Logger.info("[AttendanceRepository] Fetching attendance records by IDs",
      count: length(record_ids)
    )

    query = from a in AttendanceRecordSchema, where: a.id in ^record_ids

    try do
      schemas = Repo.all(query)
      records = AttendanceRecordMapper.to_domain_list(schemas)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved attendance records by IDs",
        requested: length(record_ids),
        found: length(records)
      )

      {:ok, records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during get_many_by_ids",
          error_id: ErrorIds.attendance_get_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during get_many_by_ids",
          error_id: ErrorIds.attendance_get_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during get_many_by_ids",
          error_id: ErrorIds.attendance_get_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def update(%AttendanceRecord{} = record) do
    Logger.info(
      "[AttendanceRepository] Updating attendance record",
      record_id: record.id,
      session_id: record.session_id,
      child_id: record.child_id,
      lock_version: record.lock_version
    )

    try do
      if !Repo.get(AttendanceRecordSchema, record.id) do
        Logger.info(
          "[AttendanceRepository] Attendance record not found during update",
          record_id: record.id
        )

        throw({:error, :not_found})
      end

      # Construct schema with id and lock_version from domain record for optimistic locking
      schema_with_lock = %AttendanceRecordSchema{
        id: record.id,
        lock_version: record.lock_version
      }

      attrs = AttendanceRecordMapper.to_schema(record)
      changeset = AttendanceRecordSchema.update_changeset(schema_with_lock, attrs)

      case Repo.update(changeset) do
        {:ok, updated_schema} ->
          updated_record = AttendanceRecordMapper.to_domain(updated_schema)

          Logger.info(
            "[AttendanceRepository] Successfully updated attendance record",
            record_id: updated_record.id,
            lock_version: updated_schema.lock_version
          )

          {:ok, updated_record}

        {:error, changeset} ->
          handle_changeset_error(changeset, "update")
      end
    rescue
      error in [Ecto.StaleEntryError] ->
        Logger.warning(
          "[AttendanceRepository] Optimistic lock conflict during update",
          error_id: ErrorIds.attendance_update_stale_error(),
          record_id: record.id,
          error_type: error.__struct__
        )

        {:error, :stale_data}

      error in [Ecto.ConstraintError] ->
        Logger.error(
          "[AttendanceRepository] Constraint violation during update",
          error_id: ErrorIds.attendance_update_constraint_violation(),
          record_id: record.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during update",
          error_id: ErrorIds.attendance_update_connection_error(),
          record_id: record.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error] ->
        Logger.error(
          "[AttendanceRepository] Database query error during update",
          error_id: ErrorIds.attendance_update_query_error(),
          record_id: record.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during update",
          error_id: ErrorIds.attendance_update_generic_error(),
          record_id: record.id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list_by_session(session_id) when is_binary(session_id) do
    Logger.info("[AttendanceRepository] Listing attendance records by session",
      session_id: session_id
    )

    query =
      from a in AttendanceRecordSchema,
        where: a.session_id == ^session_id,
        order_by: [asc: a.child_id]

    try do
      schemas = Repo.all(query)
      records = AttendanceRecordMapper.to_domain_list(schemas)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved attendance records by session",
        session_id: session_id,
        count: length(records)
      )

      {:ok, records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during list_by_session",
          error_id: ErrorIds.attendance_list_connection_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during list_by_session",
          error_id: ErrorIds.attendance_list_query_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during list_by_session",
          error_id: ErrorIds.attendance_list_generic_error(),
          session_id: session_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @doc """
  Retrieves attendance records for a session with enriched child name data.

  Similar to list_by_session/1 but includes child first_name and last_name fields
  by joining with the children table. Used by provider attendance view to display
  child names without separate queries.

  This is an implementation-specific method, not part of the ForManagingAttendance port.
  """
  def list_by_session_enriched(session_id) when is_binary(session_id) do
    Logger.info("[AttendanceRepository] Listing enriched attendance records by session",
      session_id: session_id
    )

    query =
      from a in AttendanceRecordSchema,
        join: c in "children",
        on: a.child_id == c.id,
        where: a.session_id == ^session_id,
        order_by: [asc: a.child_id],
        select: %{
          id: a.id,
          session_id: a.session_id,
          child_id: a.child_id,
          parent_id: a.parent_id,
          provider_id: a.provider_id,
          status: a.status,
          check_in_at: a.check_in_at,
          check_in_notes: a.check_in_notes,
          check_in_by: a.check_in_by,
          check_out_at: a.check_out_at,
          check_out_notes: a.check_out_notes,
          check_out_by: a.check_out_by,
          inserted_at: a.inserted_at,
          updated_at: a.updated_at,
          lock_version: a.lock_version,
          # Child fields for provider view
          child_first_name: c.first_name,
          child_last_name: c.last_name
        }

    try do
      enriched_records =
        query
        |> Repo.all()
        |> Enum.map(fn record ->
          # Convert status from string to atom for component compatibility
          %{record | status: String.to_existing_atom(record.status)}
        end)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved enriched attendance records by session",
        session_id: session_id,
        count: length(enriched_records)
      )

      {:ok, enriched_records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during list_by_session_enriched",
          error_id: ErrorIds.attendance_list_connection_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during list_by_session_enriched",
          error_id: ErrorIds.attendance_list_query_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during list_by_session_enriched",
          error_id: ErrorIds.attendance_list_generic_error(),
          session_id: session_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_by_child(child_id) when is_binary(child_id) do
    Logger.info("[AttendanceRepository] Listing attendance records by child", child_id: child_id)

    query =
      from a in AttendanceRecordSchema,
        join: s in ProgramSessionSchema,
        on: a.session_id == s.id,
        where: a.child_id == ^child_id,
        order_by: [desc: s.session_date, desc: s.start_time]

    try do
      schemas = Repo.all(query)
      records = AttendanceRecordMapper.to_domain_list(schemas)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved attendance records by child",
        child_id: child_id,
        count: length(records)
      )

      {:ok, records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during list_by_child",
          error_id: ErrorIds.attendance_list_connection_error(),
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during list_by_child",
          error_id: ErrorIds.attendance_list_query_error(),
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during list_by_child",
          error_id: ErrorIds.attendance_list_generic_error(),
          child_id: child_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_by_parent(parent_id) when is_binary(parent_id) do
    Logger.info("[AttendanceRepository] Listing attendance records by parent",
      parent_id: parent_id
    )

    query =
      from a in AttendanceRecordSchema,
        join: s in ProgramSessionSchema,
        on: a.session_id == s.id,
        join: p in PrimeYouth.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema,
        on: s.program_id == p.id,
        join: c in "children",
        on: a.child_id == c.id,
        where: a.parent_id == ^parent_id,
        order_by: [desc: s.session_date, desc: s.start_time],
        select: %{
          id: a.id,
          session_id: a.session_id,
          child_id: a.child_id,
          parent_id: a.parent_id,
          provider_id: a.provider_id,
          status: a.status,
          check_in_at: a.check_in_at,
          check_in_notes: a.check_in_notes,
          check_in_by: a.check_in_by,
          check_out_at: a.check_out_at,
          check_out_notes: a.check_out_notes,
          check_out_by: a.check_out_by,
          inserted_at: a.inserted_at,
          updated_at: a.updated_at,
          lock_version: a.lock_version,
          # Session fields for parent view
          session_date: s.session_date,
          session_start_time: s.start_time,
          # Program fields for parent view
          program_name: p.title,
          # Child fields for parent view
          child_first_name: c.first_name,
          child_last_name: c.last_name
        }

    try do
      enriched_records =
        query
        |> Repo.all()
        |> Enum.map(fn record ->
          # Convert status from string to atom for component compatibility
          %{record | status: String.to_existing_atom(record.status)}
        end)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved enriched attendance records by parent",
        parent_id: parent_id,
        count: length(enriched_records)
      )

      {:ok, enriched_records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during list_by_parent",
          error_id: ErrorIds.attendance_list_connection_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during list_by_parent",
          error_id: ErrorIds.attendance_list_query_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during list_by_parent",
          error_id: ErrorIds.attendance_list_generic_error(),
          parent_id: parent_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def check_in_atomic(session_id, child_id, provider_id, notes \\ nil) do
    Logger.info(
      "[AttendanceRepository] Performing atomic check-in",
      session_id: session_id,
      child_id: child_id,
      provider_id: provider_id
    )

    now = DateTime.utc_now()

    attrs = %{
      session_id: session_id,
      child_id: child_id,
      provider_id: provider_id,
      status: "checked_in",
      check_in_at: now,
      check_in_notes: notes,
      check_in_by: provider_id
    }

    changeset = AttendanceRecordSchema.changeset(%AttendanceRecordSchema{}, attrs)

    try do
      case Repo.insert(
             changeset,
             on_conflict:
               {:replace, [:status, :check_in_at, :check_in_notes, :check_in_by, :updated_at]},
             conflict_target: [:session_id, :child_id],
             returning: true
           ) do
        {:ok, schema} ->
          record = AttendanceRecordMapper.to_domain(schema)

          Logger.info(
            "[AttendanceRepository] Successfully performed atomic check-in",
            record_id: record.id,
            session_id: record.session_id,
            child_id: record.child_id,
            status: record.status
          )

          {:ok, record}

        {:error, changeset} ->
          handle_changeset_error(changeset, "check_in_atomic")
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during check_in_atomic",
          error_id: ErrorIds.attendance_create_connection_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during check_in_atomic",
          error_id: ErrorIds.attendance_create_query_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during check_in_atomic",
          error_id: ErrorIds.attendance_create_generic_error(),
          session_id: session_id,
          child_id: child_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_by_session_ids(session_ids) when is_list(session_ids) do
    Logger.info("[AttendanceRepository] Listing attendance records by session IDs",
      count: length(session_ids)
    )

    query =
      from a in AttendanceRecordSchema,
        where: a.session_id in ^session_ids,
        order_by: [asc: a.session_id, asc: a.child_id]

    try do
      schemas = Repo.all(query)
      records = AttendanceRecordMapper.to_domain_list(schemas)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved attendance records by session IDs",
        session_count: length(session_ids),
        record_count: length(records)
      )

      {:ok, records}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during list_by_session_ids",
          error_id: ErrorIds.attendance_list_connection_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[AttendanceRepository] Database query error during list_by_session_ids",
          error_id: ErrorIds.attendance_list_query_error(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during list_by_session_ids",
          error_id: ErrorIds.attendance_list_generic_error(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  defp handle_changeset_error(changeset, operation) do
    case extract_constraint_error(changeset) do
      {:unique, "attendance_records_session_id_child_id_index"} ->
        Logger.warning(
          "[AttendanceRepository] Duplicate attendance record during #{operation}",
          error_id: ErrorIds.attendance_duplicate_error(),
          errors: changeset.errors
        )

        {:error, :duplicate_attendance}

      {:constraint, _name} ->
        Logger.error(
          "[AttendanceRepository] Database constraint error during #{operation}",
          error_id: ErrorIds.attendance_update_constraint_violation(),
          errors: changeset.errors
        )

        {:error, :database_query_error}

      nil ->
        Logger.warning(
          "[AttendanceRepository] Changeset validation failed during #{operation}",
          error_id: ErrorIds.attendance_validation_error(),
          errors: changeset.errors
        )

        {:error, :database_query_error}
    end
  end

  defp extract_constraint_error(changeset) do
    Enum.find_value(changeset.errors, fn
      {_field, {_msg, [constraint: :unique, constraint_name: name]}} ->
        {:unique, name}

      {_field, {_msg, [constraint: _type, constraint_name: name]}} ->
        {:constraint, name}

      _ ->
        nil
    end)
  end
end

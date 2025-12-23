defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.AttendanceRepository do
  @moduledoc """
  Repository implementation for attendance record persistence.

  Implements ForManagingAttendance port with:
  - Optimistic locking for concurrent update protection
  - Atomic batch operations using Ecto.Multi
  - Comprehensive error handling
  """

  @behaviour PrimeYouth.Attendance.Domain.Ports.ForManagingAttendance

  import Ecto.Query

  alias Ecto.Multi
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
  def update(%AttendanceRecord{} = record) do
    Logger.info(
      "[AttendanceRepository] Updating attendance record",
      record_id: record.id,
      session_id: record.session_id,
      child_id: record.child_id
    )

    try do
      if !Repo.get(AttendanceRecordSchema, record.id) do
        Logger.info(
          "[AttendanceRepository] Attendance record not found during update",
          record_id: record.id
        )

        throw({:error, :not_found})
      end

      current_schema = Repo.get!(AttendanceRecordSchema, record.id)
      attrs = AttendanceRecordMapper.to_schema(record)
      changeset = AttendanceRecordSchema.update_changeset(current_schema, attrs)

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
        where: a.parent_id == ^parent_id,
        order_by: [desc: s.session_date, desc: s.start_time]

    try do
      schemas = Repo.all(query)
      records = AttendanceRecordMapper.to_domain_list(schemas)

      Logger.info(
        "[AttendanceRepository] Successfully retrieved attendance records by parent",
        parent_id: parent_id,
        count: length(records)
      )

      {:ok, records}
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
  def submit_batch(session_id, attendance_records, submitted_by_user_id)
      when is_binary(session_id) and is_list(attendance_records) and
             is_binary(submitted_by_user_id) do
    Logger.info(
      "[AttendanceRepository] Submitting batch of attendance records",
      session_id: session_id,
      record_count: length(attendance_records),
      submitted_by: submitted_by_user_id
    )

    multi =
      attendance_records
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {record, index}, multi ->
        Multi.run(multi, {:update, index}, fn repo, _changes ->
          case repo.get(AttendanceRecordSchema, record.id) do
            nil ->
              {:error, :not_found}

            schema ->
              attrs = %{
                submitted: true,
                submitted_at: DateTime.utc_now(),
                submitted_by: parse_uuid(submitted_by_user_id)
              }

              changeset = AttendanceRecordSchema.update_changeset(schema, attrs)

              repo.update(changeset)
          end
        end)
      end)

    try do
      case Repo.transaction(multi) do
        {:ok, results} ->
          updated_schemas =
            results
            |> Map.values()
            |> Enum.filter(&is_struct(&1, AttendanceRecordSchema))

          updated_records = AttendanceRecordMapper.to_domain_list(updated_schemas)

          Logger.info(
            "[AttendanceRepository] Successfully submitted batch of attendance records",
            session_id: session_id,
            submitted_count: length(updated_records)
          )

          {:ok, updated_records}

        {:error, _failed_operation, failed_value, _changes_so_far} ->
          Logger.error(
            "[AttendanceRepository] Batch submission failed",
            error_id: ErrorIds.attendance_batch_error(),
            session_id: session_id,
            failure_reason: inspect(failed_value)
          )

          case failed_value do
            %Ecto.Changeset{} ->
              {:error, :database_query_error}

            :not_found ->
              {:error, :not_found}

            _ ->
              {:error, :database_unavailable}
          end
      end
    rescue
      error in [Ecto.StaleEntryError] ->
        Logger.warning(
          "[AttendanceRepository] Optimistic lock conflict during batch submission",
          error_id: ErrorIds.attendance_batch_stale_error(),
          session_id: session_id,
          error_type: error.__struct__
        )

        {:error, :stale_data}

      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[AttendanceRepository] Database connection failed during batch submission",
          error_id: ErrorIds.attendance_batch_connection_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error] ->
        Logger.error(
          "[AttendanceRepository] Database query error during batch submission",
          error_id: ErrorIds.attendance_batch_query_error(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[AttendanceRepository] Unexpected database error during batch submission",
          error_id: ErrorIds.attendance_batch_generic_error(),
          session_id: session_id,
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

  defp parse_uuid(uuid_string) when is_binary(uuid_string) do
    case Ecto.UUID.dump(uuid_string) do
      {:ok, binary} -> binary
      :error -> uuid_string
    end
  end

  defp parse_uuid(other), do: other
end

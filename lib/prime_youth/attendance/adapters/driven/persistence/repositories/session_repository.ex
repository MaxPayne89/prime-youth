defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.SessionRepository do
  @moduledoc """
  Repository implementation for program session persistence.

  Implements ForManagingSessions port with domain entity mapping
  and comprehensive error handling.
  """

  @behaviour PrimeYouth.Attendance.Domain.Ports.ForManagingSessions

  import Ecto.Query

  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Mappers.ProgramSessionMapper
  alias PrimeYouth.Attendance.Adapters.Driven.Persistence.Schemas.ProgramSessionSchema
  alias PrimeYouth.Attendance.Domain.Models.ProgramSession
  alias PrimeYouth.Repo
  alias PrimeYouthWeb.ErrorIds

  require Logger

  @impl true
  def create(%ProgramSession{} = session) do
    Logger.info(
      "[SessionRepository] Creating session",
      program_id: session.program_id,
      session_date: session.session_date,
      start_time: session.start_time
    )

    attrs = ProgramSessionMapper.to_schema(session)
    changeset = ProgramSessionSchema.changeset(%ProgramSessionSchema{}, attrs)

    try do
      case Repo.insert(changeset) do
        {:ok, schema} ->
          created_session = ProgramSessionMapper.to_domain(schema)

          Logger.info(
            "[SessionRepository] Successfully created session",
            session_id: created_session.id,
            program_id: created_session.program_id
          )

          {:ok, created_session}

        {:error, changeset} ->
          handle_changeset_error(changeset, "create")
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[SessionRepository] Database connection failed during create",
          error_id: ErrorIds.generate(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[SessionRepository] Database query error during create",
          error_id: ErrorIds.generate(),
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[SessionRepository] Unexpected database error during create",
          error_id: ErrorIds.generate(),
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_by_id(session_id) when is_binary(session_id) do
    Logger.info("[SessionRepository] Fetching session by ID", session_id: session_id)

    query = from s in ProgramSessionSchema, where: s.id == ^session_id

    try do
      case Repo.one(query) do
        nil ->
          Logger.info("[SessionRepository] Session not found", session_id: session_id)
          {:error, :not_found}

        schema ->
          session = ProgramSessionMapper.to_domain(schema)

          Logger.info(
            "[SessionRepository] Successfully retrieved session",
            session_id: session.id,
            program_id: session.program_id
          )

          {:ok, session}
      end
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[SessionRepository] Database connection failed during get_by_id",
          error_id: ErrorIds.generate(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[SessionRepository] Database query error during get_by_id",
          error_id: ErrorIds.generate(),
          session_id: session_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[SessionRepository] Unexpected database error during get_by_id",
          error_id: ErrorIds.generate(),
          session_id: session_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_by_program(program_id) when is_binary(program_id) do
    Logger.info("[SessionRepository] Listing sessions by program", program_id: program_id)

    query =
      from s in ProgramSessionSchema,
        where: s.program_id == ^program_id,
        order_by: [asc: s.session_date, asc: s.start_time]

    try do
      schemas = Repo.all(query)
      sessions = ProgramSessionMapper.to_domain_list(schemas)

      Logger.info(
        "[SessionRepository] Successfully retrieved sessions by program",
        program_id: program_id,
        count: length(sessions)
      )

      {:ok, sessions}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[SessionRepository] Database connection failed during list_by_program",
          error_id: ErrorIds.generate(),
          program_id: program_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[SessionRepository] Database query error during list_by_program",
          error_id: ErrorIds.generate(),
          program_id: program_id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[SessionRepository] Unexpected database error during list_by_program",
          error_id: ErrorIds.generate(),
          program_id: program_id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def list_today_sessions(%Date{} = date) do
    Logger.info("[SessionRepository] Listing sessions for date", date: date)

    query =
      from s in ProgramSessionSchema,
        where: s.session_date == ^date,
        order_by: [asc: s.start_time]

    try do
      schemas = Repo.all(query)
      sessions = ProgramSessionMapper.to_domain_list(schemas)

      Logger.info(
        "[SessionRepository] Successfully retrieved sessions for date",
        date: date,
        count: length(sessions)
      )

      {:ok, sessions}
    rescue
      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[SessionRepository] Database connection failed during list_today_sessions",
          error_id: ErrorIds.generate(),
          date: date,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error, Ecto.Query.CastError] ->
        Logger.error(
          "[SessionRepository] Database query error during list_today_sessions",
          error_id: ErrorIds.generate(),
          date: date,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[SessionRepository] Unexpected database error during list_today_sessions",
          error_id: ErrorIds.generate(),
          date: date,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    end
  end

  @impl true
  def update(%ProgramSession{} = session) do
    Logger.info(
      "[SessionRepository] Updating session",
      session_id: session.id,
      program_id: session.program_id
    )

    try do
      if !Repo.get(ProgramSessionSchema, session.id) do
        Logger.info("[SessionRepository] Session not found during update", session_id: session.id)
        throw({:error, :not_found})
      end

      current_schema = Repo.get!(ProgramSessionSchema, session.id)
      attrs = ProgramSessionMapper.to_schema(session)
      changeset = ProgramSessionSchema.changeset(current_schema, attrs)

      case Repo.update(changeset) do
        {:ok, updated_schema} ->
          updated_session = ProgramSessionMapper.to_domain(updated_schema)

          Logger.info(
            "[SessionRepository] Successfully updated session",
            session_id: updated_session.id,
            program_id: updated_session.program_id
          )

          {:ok, updated_session}

        {:error, changeset} ->
          handle_changeset_error(changeset, "update")
      end
    rescue
      error in [Ecto.ConstraintError] ->
        Logger.error(
          "[SessionRepository] Constraint violation during update",
          error_id: ErrorIds.generate(),
          session_id: session.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error in [DBConnection.ConnectionError] ->
        Logger.error(
          "[SessionRepository] Database connection failed during update",
          error_id: ErrorIds.generate(),
          session_id: session.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_connection_error}

      error in [Postgrex.Error] ->
        Logger.error(
          "[SessionRepository] Database query error during update",
          error_id: ErrorIds.generate(),
          session_id: session.id,
          error_type: error.__struct__,
          error_message: Exception.message(error)
        )

        {:error, :database_query_error}

      error ->
        Logger.error(
          "[SessionRepository] Unexpected database error during update",
          error_id: ErrorIds.generate(),
          session_id: session.id,
          error_type: error.__struct__,
          stacktrace: Exception.format(:error, error, __STACKTRACE__)
        )

        {:error, :database_unavailable}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_changeset_error(changeset, operation) do
    case extract_constraint_error(changeset) do
      {:unique, "program_sessions_program_id_session_date_start_time_index"} ->
        Logger.warning(
          "[SessionRepository] Duplicate session during #{operation}",
          error_id: ErrorIds.generate(),
          errors: changeset.errors
        )

        {:error, :duplicate_session}

      {:constraint, _name} ->
        Logger.error(
          "[SessionRepository] Database constraint error during #{operation}",
          error_id: ErrorIds.generate(),
          errors: changeset.errors
        )

        {:error, :database_query_error}

      nil ->
        Logger.warning(
          "[SessionRepository] Changeset validation failed during #{operation}",
          error_id: ErrorIds.generate(),
          errors: changeset.errors
        )

        {:error, :database_query_error}
    end
  end

  defp extract_constraint_error(changeset) do
    Enum.find_value(changeset.errors, fn
      {_field, {_msg, [constraint: :unique, constraint_name: name]}} ->
        {:unique, name}

      {_field, {_msg, [constraint: type, constraint_name: name]}} ->
        {:constraint, name}

      _ ->
        nil
    end)
  end
end

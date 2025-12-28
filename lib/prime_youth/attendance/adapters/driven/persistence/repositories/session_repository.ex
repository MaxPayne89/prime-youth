defmodule PrimeYouth.Attendance.Adapters.Driven.Persistence.Repositories.SessionRepository do
  @moduledoc """
  Repository implementation for program session persistence.

  Implements ForManagingSessions port with:
  - Domain entity mapping via ProgramSessionMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
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
  end

  @impl true
  def get_by_id(session_id) when is_binary(session_id) do
    Logger.info("[SessionRepository] Fetching session by ID", session_id: session_id)

    case Repo.get(ProgramSessionSchema, session_id) do
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
  end

  @impl true
  def list_by_program(program_id) when is_binary(program_id) do
    Logger.info("[SessionRepository] Listing sessions by program", program_id: program_id)

    sessions =
      ProgramSessionSchema
      |> where([s], s.program_id == ^program_id)
      |> order_by([s], asc: s.session_date, asc: s.start_time)
      |> Repo.all()
      |> ProgramSessionMapper.to_domain_list()

    Logger.info(
      "[SessionRepository] Successfully retrieved sessions by program",
      program_id: program_id,
      count: length(sessions)
    )

    sessions
  end

  @impl true
  def list_today_sessions(%Date{} = date) do
    Logger.info("[SessionRepository] Listing sessions for date", date: date)

    sessions =
      ProgramSessionSchema
      |> where([s], s.session_date == ^date)
      |> order_by([s], asc: s.start_time)
      |> Repo.all()
      |> ProgramSessionMapper.to_domain_list()

    Logger.info(
      "[SessionRepository] Successfully retrieved sessions for date",
      date: date,
      count: length(sessions)
    )

    sessions
  end

  @impl true
  def update(%ProgramSession{} = session) do
    Logger.info(
      "[SessionRepository] Updating session",
      session_id: session.id,
      program_id: session.program_id,
      lock_version: session.lock_version
    )

    case Repo.get(ProgramSessionSchema, session.id) do
      nil ->
        Logger.info("[SessionRepository] Session not found during update", session_id: session.id)
        {:error, :not_found}

      current_schema ->
        do_update(current_schema, session)
    end
  rescue
    Ecto.StaleEntryError ->
      Logger.warning(
        "[SessionRepository] Optimistic lock conflict during update",
        error_id: ErrorIds.session_update_stale_error(),
        session_id: session.id
      )

      {:error, :stale_data}
  end

  defp do_update(current_schema, session) do
    schema_with_client_version = %{current_schema | lock_version: session.lock_version || 1}

    attrs = ProgramSessionMapper.to_schema(session)
    changeset = ProgramSessionSchema.update_changeset(schema_with_client_version, attrs)

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
  end

  defp handle_changeset_error(changeset, operation) do
    case extract_constraint_error(changeset) do
      {:unique, "program_sessions_program_id_session_date_start_time_index"} ->
        Logger.warning(
          "[SessionRepository] Duplicate session during #{operation}",
          error_id: ErrorIds.session_duplicate_error(),
          errors: changeset.errors
        )

        {:error, :duplicate_session}

      _other ->
        Logger.warning(
          "[SessionRepository] Changeset validation failed during #{operation}",
          error_id: ErrorIds.session_validation_error(),
          errors: changeset.errors
        )

        {:error, changeset}
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

  @impl true
  def list_by_provider_and_date(provider_id, %Date{} = date) when is_binary(provider_id) do
    Logger.info(
      "[SessionRepository] Listing sessions by provider and date",
      provider_id: provider_id,
      date: date
    )

    sessions =
      ProgramSessionSchema
      |> where([s], s.session_date == ^date)
      |> order_by([s], asc: s.start_time)
      |> Repo.all()
      |> ProgramSessionMapper.to_domain_list()

    Logger.info(
      "[SessionRepository] Successfully retrieved sessions by provider and date",
      provider_id: provider_id,
      date: date,
      count: length(sessions)
    )

    sessions
  end

  @impl true
  def get_many_by_ids(session_ids) when is_list(session_ids) do
    Logger.info("[SessionRepository] Fetching sessions by IDs", count: length(session_ids))

    sessions =
      ProgramSessionSchema
      |> where([s], s.id in ^session_ids)
      |> Repo.all()
      |> ProgramSessionMapper.to_domain_list()

    Logger.info(
      "[SessionRepository] Successfully retrieved sessions by IDs",
      requested: length(session_ids),
      found: length(sessions)
    )

    sessions
  end
end

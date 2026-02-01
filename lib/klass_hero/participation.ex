defmodule KlassHero.Participation do
  @moduledoc """
  Public API for the Participation bounded context.

  This module provides the public interface for managing session participation,
  check-ins, check-outs, and attendance tracking.

  ## Usage

      # Session Management
      {:ok, session} = Participation.create_session(%{
        program_id: "prog-uuid",
        session_date: ~D[2024-01-15],
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00]
      })
      {:ok, session} = Participation.start_session("session-uuid")
      {:ok, session} = Participation.complete_session("session-uuid")
      sessions = Participation.list_sessions(%{program_id: "prog-uuid"})

      # Participation Records
      {:ok, record} = Participation.record_check_in(%{
        record_id: "record-uuid",
        checked_in_by: "provider-uuid"
      })
      {:ok, record} = Participation.record_check_out(%{
        record_id: "record-uuid",
        checked_out_by: "provider-uuid"
      })

  ## Architecture

  This context follows the Ports & Adapters architecture:
  - Public API (this module) → delegates to use cases
  - Use cases (application layer) → orchestrate domain operations
  - Repository ports (domain layer) → define persistence contracts
  - Repository implementations (adapter layer) → implement persistence
  """

  alias KlassHero.Participation.Application.UseCases.BulkCheckIn
  alias KlassHero.Participation.Application.UseCases.CompleteSession
  alias KlassHero.Participation.Application.UseCases.CreateSession
  alias KlassHero.Participation.Application.UseCases.GetApprovedBehavioralNotes
  alias KlassHero.Participation.Application.UseCases.GetBehavioralNoteForRecord
  alias KlassHero.Participation.Application.UseCases.GetParticipationHistory
  alias KlassHero.Participation.Application.UseCases.GetParticipationRecord
  alias KlassHero.Participation.Application.UseCases.GetSessionWithRoster
  alias KlassHero.Participation.Application.UseCases.ListPendingBehavioralNotes
  alias KlassHero.Participation.Application.UseCases.ListProviderSessions
  alias KlassHero.Participation.Application.UseCases.ListSessions
  alias KlassHero.Participation.Application.UseCases.RecordCheckIn
  alias KlassHero.Participation.Application.UseCases.RecordCheckOut
  alias KlassHero.Participation.Application.UseCases.ReviewBehavioralNote
  alias KlassHero.Participation.Application.UseCases.ReviseBehavioralNote
  alias KlassHero.Participation.Application.UseCases.StartSession
  alias KlassHero.Participation.Application.UseCases.SubmitBehavioralNote

  # ============================================================================
  # Session Management
  # ============================================================================

  @doc """
  Creates a new program session.

  ## Parameters

  - `params` - Map containing:
    - `program_id` - (required) ID of the program
    - `session_date` - (required) Date of the session
    - `start_time` - (required) Session start time
    - `end_time` - (required) Session end time
    - `location` - (optional) Session location
    - `notes` - (optional) Session notes
    - `max_capacity` - (optional) Maximum capacity

  ## Returns

  - `{:ok, session}` on success
  - `{:error, :invalid_time_range}` if end_time <= start_time
  - `{:error, :duplicate_session}` if session already exists
  """
  def create_session(params) when is_map(params) do
    CreateSession.execute(params)
  end

  @doc """
  Starts a scheduled session.

  ## Parameters

  - `session_id` - ID of the session to start

  ## Returns

  - `{:ok, session}` on success
  - `{:error, :not_found}` if session doesn't exist
  - `{:error, :invalid_status_transition}` if not in :scheduled status
  """
  def start_session(session_id) when is_binary(session_id) do
    StartSession.execute(session_id)
  end

  @doc """
  Completes an in-progress session.

  Marks all registered (not checked in) children as absent.

  ## Parameters

  - `session_id` - ID of the session to complete

  ## Returns

  - `{:ok, session}` on success
  - `{:error, :not_found}` if session doesn't exist
  - `{:error, :invalid_status_transition}` if not in :in_progress status
  """
  def complete_session(session_id) when is_binary(session_id) do
    CompleteSession.execute(session_id)
  end

  @doc """
  Lists sessions based on filter criteria.

  ## Parameters

  - `params` - Map containing filter options:
    - `program_id` - Filter by program ID
    - `date` - Filter by specific date

  ## Returns

  List of sessions matching the criteria.
  """
  def list_sessions(params \\ %{}) when is_map(params) do
    ListSessions.execute(params)
  end

  @doc """
  Lists sessions for a provider on a specific date.

  ## Parameters

  - `provider_id` - ID of the provider
  - `date` - Date to filter by (defaults to today)

  ## Returns

  `{:ok, sessions}` - List of sessions assigned to the provider.
  """
  def list_provider_sessions(provider_id, date \\ nil) when is_binary(provider_id) do
    params = %{provider_id: provider_id}
    params = if date, do: Map.put(params, :date, date), else: params
    ListProviderSessions.execute(params)
  end

  @doc """
  Retrieves a session with its complete roster.

  ## Parameters

  - `session_id` - ID of the session

  ## Returns

  - `{:ok, %{session: session, roster: roster}}` on success
  - `{:error, :not_found}` if session doesn't exist
  """
  def get_session_with_roster(session_id) when is_binary(session_id) do
    GetSessionWithRoster.execute(session_id)
  end

  @doc """
  Retrieves a session with participation records attached for UI display.

  Returns the session with a `participation_records` field containing
  enriched records with child names resolved.

  ## Parameters

  - `session_id` - ID of the session

  ## Returns

  - `{:ok, session}` where session has `participation_records` list
  - `{:error, :not_found}` if session doesn't exist
  """
  def get_session_with_roster_enriched(session_id) when is_binary(session_id) do
    GetSessionWithRoster.execute_enriched(session_id)
  end

  # ============================================================================
  # Participation Records
  # ============================================================================

  @doc """
  Checks in a child to a session.

  ## Parameters

  - `params` - Map containing:
    - `record_id` - ID of the participation record
    - `checked_in_by` - ID of the user performing check-in
    - `notes` - Optional check-in notes

  ## Returns

  - `{:ok, record}` on success
  - `{:error, :not_found}` if record doesn't exist
  - `{:error, :invalid_status_transition}` if not in :registered status
  """
  def record_check_in(params) when is_map(params) do
    RecordCheckIn.execute(params)
  end

  @doc """
  Checks out a child from a session.

  ## Parameters

  - `params` - Map containing:
    - `record_id` - ID of the participation record
    - `checked_out_by` - ID of the user performing check-out
    - `notes` - Optional check-out notes

  ## Returns

  - `{:ok, record}` on success
  - `{:error, :not_found}` if record doesn't exist
  - `{:error, :invalid_status_transition}` if not in :checked_in status
  """
  def record_check_out(params) when is_map(params) do
    RecordCheckOut.execute(params)
  end

  @doc """
  Checks in multiple children to a session at once.

  ## Parameters

  - `params` - Map containing:
    - `record_ids` - List of participation record IDs to check in
    - `checked_in_by` - ID of the user performing check-ins
    - `notes` - Optional notes to apply to all check-ins

  ## Returns

  Map with:
  - `successful` - List of successfully checked-in records
  - `failed` - List of {record_id, error_reason} tuples
  """
  def bulk_check_in(params) when is_map(params) do
    BulkCheckIn.execute(params)
  end

  @doc """
  Retrieves a participation record by ID.

  ## Parameters

  - `record_id` - ID of the participation record

  ## Returns

  - `{:ok, record}` on success
  - `{:error, :not_found}` if record doesn't exist
  """
  def get_participation_record(record_id) when is_binary(record_id) do
    GetParticipationRecord.execute(record_id)
  end

  @doc """
  Retrieves participation history for one or more children.

  ## Parameters

  - `params` - Map containing either:
    - `child_id` - ID of a single child
    - `child_ids` - List of child IDs for fetching multiple children's history
    - `start_date` - Optional start of date range
    - `end_date` - Optional end of date range

  ## Returns

  `{:ok, records}` - List of participation records, ordered by date descending.
  """
  def get_participation_history(params) when is_map(params) do
    GetParticipationHistory.execute(params)
  end

  # ============================================================================
  # Behavioral Notes
  # ============================================================================

  @doc """
  Submits a behavioral note for a participation record.

  ## Parameters

  - `params` - Map containing:
    - `participation_record_id` - ID of the participation record
    - `provider_id` - ID of the provider
    - `content` - Note content (max 1000 chars)

  ## Returns

  - `{:ok, note}` on success
  - `{:error, reason}` on failure
  """
  def submit_behavioral_note(params) when is_map(params) do
    SubmitBehavioralNote.execute(params)
  end

  @doc """
  Reviews a behavioral note (approve or reject).

  ## Parameters

  - `params` - Map containing:
    - `note_id` - ID of the note
    - `parent_id` - ID of the parent (ownership enforced at DB level)
    - `decision` - `:approve` or `:reject`
    - `reason` - Optional rejection reason

  ## Returns

  - `{:ok, note}` on success
  - `{:error, reason}` on failure
  """
  def review_behavioral_note(params) when is_map(params) do
    ReviewBehavioralNote.execute(params)
  end

  @doc """
  Revises a rejected behavioral note with new content.

  ## Parameters

  - `params` - Map containing:
    - `note_id` - ID of the note
    - `provider_id` - ID of the provider (ownership enforced at DB level)
    - `content` - New content

  ## Returns

  - `{:ok, note}` on success
  - `{:error, reason}` on failure
  """
  def revise_behavioral_note(params) when is_map(params) do
    ReviseBehavioralNote.execute(params)
  end

  @doc """
  Lists pending behavioral notes for a parent.

  ## Returns

  `{:ok, notes}` - List of notes awaiting review.
  """
  def list_pending_behavioral_notes(parent_id) when is_binary(parent_id) do
    ListPendingBehavioralNotes.execute(parent_id)
  end

  @doc """
  Gets approved behavioral notes for a child.

  ## Returns

  `{:ok, notes}` - List of approved notes.
  """
  def get_approved_behavioral_notes(child_id) when is_binary(child_id) do
    GetApprovedBehavioralNotes.execute(child_id)
  end

  @doc """
  Gets a behavioral note by participation record and provider.

  ## Returns

  - `{:ok, note}` if found
  - `{:error, :not_found}` if no note exists
  """
  def get_behavioral_note_by_record_and_provider(record_id, provider_id)
      when is_binary(record_id) and is_binary(provider_id) do
    GetBehavioralNoteForRecord.execute(record_id, provider_id)
  end

  @doc """
  Lists behavioral notes for multiple participation records by a single provider.

  Returns a flat list of notes. Use this instead of calling
  `get_behavioral_note_by_record_and_provider/2` per record to avoid N+1 queries.
  """
  def list_behavioral_notes_by_records_and_provider(record_ids, provider_id)
      when is_list(record_ids) and is_binary(provider_id) do
    GetBehavioralNoteForRecord.execute_batch(record_ids, provider_id)
  end
end

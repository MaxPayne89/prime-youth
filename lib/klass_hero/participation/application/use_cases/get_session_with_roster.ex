defmodule KlassHero.Participation.Application.UseCases.GetSessionWithRoster do
  @moduledoc """
  Use case for retrieving a session with its complete roster.

  Returns session details along with all registered children and their
  participation status. Child info is resolved via the Identity context.
  """

  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

  require Logger

  @type roster_entry :: %{
          record: ParticipationRecord.t(),
          child_name: String.t(),
          child_first_name: String.t(),
          child_last_name: String.t(),
          allergies: String.t() | nil,
          support_needs: String.t() | nil,
          emergency_contact: String.t() | nil,
          behavioral_notes: [BehavioralNote.t()]
        }

  @type result ::
          {:ok, %{session: ProgramSession.t(), roster: [roster_entry()]}}
          | {:error, :not_found}

  @doc """
  Retrieves a session with its complete roster.

  ## Parameters

  - `session_id` - ID of the session

  ## Returns

  - `{:ok, %{session: session, roster: roster}}` on success
  - `{:error, :not_found}` if session doesn't exist
  """
  @spec execute(String.t()) :: result()
  def execute(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id) do
      records = participation_repository().list_by_session(session_id)
      roster = Enum.map(records, &build_roster_entry/1)

      {:ok, %{session: session, roster: roster}}
    end
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
  @spec execute_enriched(String.t()) :: {:ok, ProgramSession.t()} | {:error, :not_found}
  def execute_enriched(session_id) when is_binary(session_id) do
    with {:ok, session} <- session_repository().get_by_id(session_id) do
      records = participation_repository().list_by_session(session_id)
      enriched_records = Enum.map(records, &enrich_record/1)
      enriched_session = Map.put(session, :participation_records, enriched_records)
      {:ok, enriched_session}
    end
  end

  defp enrich_record(record) do
    info = resolve_child_info(record.child_id)
    notes = resolve_behavioral_notes(record.child_id, info.has_consent?)

    record
    |> Map.put(:child_name, "#{info.first_name} #{info.last_name}")
    |> Map.put(:child_first_name, info.first_name)
    |> Map.put(:child_last_name, info.last_name)
    |> Map.put(:allergies, info.allergies)
    |> Map.put(:support_needs, info.support_needs)
    |> Map.put(:emergency_contact, info.emergency_contact)
    |> Map.put(:behavioral_notes, notes)
  end

  defp build_roster_entry(%ParticipationRecord{} = record) do
    info = resolve_child_info(record.child_id)
    notes = resolve_behavioral_notes(record.child_id, info.has_consent?)

    %{
      record: record,
      child_name: "#{info.first_name} #{info.last_name}",
      child_first_name: info.first_name,
      child_last_name: info.last_name,
      allergies: info.allergies,
      support_needs: info.support_needs,
      emergency_contact: info.emergency_contact,
      behavioral_notes: notes
    }
  end

  # Trigger: consent check determines note visibility
  # Why: behavioral notes contain provider observations — only visible when parent consented
  # Outcome: returns approved notes list when consented, empty list otherwise
  defp resolve_behavioral_notes(_child_id, false = _has_consent?), do: []

  defp resolve_behavioral_notes(child_id, true = _has_consent?) do
    behavioral_note_repository().list_approved_by_child(child_id)
  end

  defp resolve_child_info(child_id) do
    case child_info_resolver().resolve_child_info(child_id) do
      {:ok, info} ->
        info

      # Trigger: child record deleted or ID invalid
      # Why: expected scenario — no log needed, graceful fallback
      {:error, :child_not_found} ->
        unknown_child_info()

      {:error, reason} ->
        Logger.warning("[Participation.GetSessionWithRoster] Failed to resolve child info",
          child_id: child_id,
          reason: inspect(reason)
        )

        unknown_child_info()
    end
  end

  defp unknown_child_info do
    %{
      first_name: "Unknown",
      last_name: "Child",
      allergies: nil,
      support_needs: nil,
      emergency_contact: nil,
      has_consent?: false
    }
  end

  defp session_repository do
    Application.get_env(:klass_hero, :participation)[:session_repository]
  end

  defp participation_repository do
    Application.get_env(:klass_hero, :participation)[:participation_repository]
  end

  defp child_info_resolver do
    Application.get_env(:klass_hero, :participation)[:child_info_resolver]
  end

  defp behavioral_note_repository do
    Application.get_env(:klass_hero, :participation)[:behavioral_note_repository]
  end
end

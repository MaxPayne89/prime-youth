defmodule KlassHero.Participation.Application.UseCases.GetSessionWithRoster do
  @moduledoc """
  Use case for retrieving a session with its complete roster.

  Returns session details along with all registered children and their
  participation status. Child info is resolved via the Identity context.
  """

  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

  @session_repository Application.compile_env!(:klass_hero, [:participation, :session_repository])
  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])
  @child_info_resolver Application.compile_env!(:klass_hero, [
                         :participation,
                         :child_info_resolver
                       ])
  @behavioral_note_repository Application.compile_env!(:klass_hero, [
                                :participation,
                                :behavioral_note_repository
                              ])

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
    with {:ok, session} <- @session_repository.get_by_id(session_id) do
      records = @participation_repository.list_by_session(session_id)
      {child_info_map, notes_map} = batch_resolve(records)

      roster =
        Enum.map(records, fn record ->
          info = Map.get(child_info_map, record.child_id, unknown_child_info())
          notes = Map.get(notes_map, record.child_id, [])

          %{record: record}
          |> Map.merge(build_enrichment_fields(info, notes))
        end)

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
  @spec execute_enriched(String.t()) :: {:ok, map()} | {:error, :not_found}
  def execute_enriched(session_id) when is_binary(session_id) do
    with {:ok, session} <- @session_repository.get_by_id(session_id) do
      records = @participation_repository.list_by_session(session_id)
      {child_info_map, notes_map} = batch_resolve(records)

      enriched_records =
        Enum.map(records, fn record ->
          info = Map.get(child_info_map, record.child_id, unknown_child_info())
          notes = Map.get(notes_map, record.child_id, [])

          # Trigger: record is a struct — Map.put on structs bypasses struct enforcement
          # Why: convert to plain map so presentation fields can be safely merged
          # Outcome: downstream consumers (templates) get a flat map with all fields
          Map.from_struct(record)
          |> Map.merge(build_enrichment_fields(info, notes))
        end)

      # Trigger: session is a struct — Map.put on structs bypasses struct enforcement
      # Why: convert to plain map so presentation field (:participation_records) can be merged
      # Outcome: returns a plain map with all session fields + enriched records
      enriched_session =
        Map.from_struct(session)
        |> Map.put(:participation_records, enriched_records)

      {:ok, enriched_session}
    end
  end

  # Trigger: records list may contain N children requiring info + notes
  # Why: batch resolution eliminates N+1 queries — single round-trip per resource type
  # Outcome: returns {child_info_map, notes_map} for O(1) lookup per record
  defp batch_resolve(records) do
    child_ids = records |> Enum.map(& &1.child_id) |> Enum.uniq()
    child_info_map = @child_info_resolver.resolve_children_info(child_ids)

    # Trigger: consent check determines note visibility
    # Why: behavioral notes contain provider observations — only visible when parent consented
    # Outcome: only fetch notes for children with active consent
    consented_child_ids =
      child_info_map
      |> Enum.filter(fn {_id, info} -> info.has_consent? end)
      |> Enum.map(fn {id, _info} -> id end)

    notes_map =
      if consented_child_ids == [] do
        %{}
      else
        @behavioral_note_repository.list_approved_by_children(consented_child_ids)
      end

    {child_info_map, notes_map}
  end

  defp build_enrichment_fields(child_info, notes) do
    %{
      child_name: "#{child_info.first_name} #{child_info.last_name}",
      child_first_name: child_info.first_name,
      child_last_name: child_info.last_name,
      allergies: child_info.allergies,
      support_needs: child_info.support_needs,
      emergency_contact: child_info.emergency_contact,
      behavioral_notes: notes
    }
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
end

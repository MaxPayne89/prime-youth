defmodule KlassHero.Participation.Application.UseCases.GetSessionWithRoster do
  @moduledoc """
  Use case for retrieving a session with its complete roster.

  Returns session details along with all registered children and their
  participation status. Child names are resolved via the Identity context.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

  require Logger

  @type roster_entry :: %{
          record: ParticipationRecord.t(),
          child_name: String.t()
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
    child_name = resolve_name(record.child_id)
    {first_name, last_name} = split_name(child_name)
    safety_info = resolve_safety_info(record.child_id)

    record
    |> Map.put(:child_name, child_name)
    |> Map.put(:child_first_name, first_name)
    |> Map.put(:child_last_name, last_name)
    |> Map.put(:allergies, safety_field(safety_info, :allergies))
    |> Map.put(:support_needs, safety_field(safety_info, :support_needs))
    |> Map.put(:emergency_contact, safety_field(safety_info, :emergency_contact))
  end

  defp build_roster_entry(%ParticipationRecord{} = record) do
    child_name = resolve_name(record.child_id)
    {first_name, last_name} = split_name(child_name)
    safety_info = resolve_safety_info(record.child_id)

    %{
      record: record,
      child_name: child_name,
      child_first_name: first_name,
      child_last_name: last_name,
      allergies: safety_field(safety_info, :allergies),
      support_needs: safety_field(safety_info, :support_needs),
      emergency_contact: safety_field(safety_info, :emergency_contact)
    }
  end

  defp resolve_name(child_id) do
    case child_name_resolver().resolve_child_name(child_id) do
      {:ok, name} ->
        name

      # Trigger: child record deleted or ID invalid
      # Why: expected scenario — no log needed, graceful fallback
      {:error, :child_not_found} ->
        "Unknown Child"

      {:error, reason} ->
        Logger.warning("[Participation.GetSessionWithRoster] Failed to resolve child name",
          child_id: child_id,
          reason: inspect(reason)
        )

        "Unknown Child"
    end
  end

  defp resolve_safety_info(child_id) do
    case child_safety_info_resolver().resolve_child_safety_info(child_id) do
      {:ok, info} ->
        info

      # Trigger: child record deleted or ID invalid
      # Why: expected scenario — no log needed, graceful fallback
      {:error, :child_not_found} ->
        nil

      {:error, reason} ->
        Logger.warning("[Participation.GetSessionWithRoster] Failed to resolve child safety info",
          child_id: child_id,
          reason: inspect(reason)
        )

        nil
    end
  end

  # Splits "FirstName LastName" into {first, last}, handling edge cases
  defp split_name(full_name) when is_binary(full_name) do
    case String.split(full_name, " ", parts: 2) do
      [first, last] -> {first, last}
      [single] -> {single, ""}
    end
  end

  # Extracts a field from safety info, returning nil when info is nil (no consent)
  defp safety_field(nil, _key), do: nil
  defp safety_field(info, key) when is_map(info), do: Map.get(info, key)

  defp session_repository do
    Application.get_env(:klass_hero, :participation)[:session_repository]
  end

  defp participation_repository do
    Application.get_env(:klass_hero, :participation)[:participation_repository]
  end

  defp child_name_resolver do
    Application.get_env(:klass_hero, :participation)[:child_name_resolver]
  end

  defp child_safety_info_resolver do
    Application.get_env(:klass_hero, :participation)[:child_safety_info_resolver]
  end
end

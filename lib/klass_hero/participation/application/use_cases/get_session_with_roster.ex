defmodule KlassHero.Participation.Application.UseCases.GetSessionWithRoster do
  @moduledoc """
  Use case for retrieving a session with its complete roster.

  Returns session details along with all registered children and their
  participation status. Child names are resolved via the Identity context.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession

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

      enriched_records =
        Enum.map(records, fn record ->
          child_name =
            case child_name_resolver().resolve_child_name(record.child_id) do
              {:ok, name} -> name
              {:error, _} -> "Unknown Child"
            end

          Map.put(record, :child_name, child_name)
        end)

      enriched_session = Map.put(session, :participation_records, enriched_records)
      {:ok, enriched_session}
    end
  end

  defp build_roster_entry(%ParticipationRecord{} = record) do
    child_name =
      case child_name_resolver().resolve_child_name(record.child_id) do
        {:ok, name} -> name
        {:error, _} -> "Unknown Child"
      end

    %{record: record, child_name: child_name}
  end

  defp session_repository do
    Application.get_env(:klass_hero, :participation)[:session_repository]
  end

  defp participation_repository do
    Application.get_env(:klass_hero, :participation)[:participation_repository]
  end

  defp child_name_resolver do
    Application.get_env(:klass_hero, :participation)[:child_name_resolver]
  end
end

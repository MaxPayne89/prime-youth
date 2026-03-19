defmodule KlassHero.Participation.Application.UseCases.BulkCheckIn do
  @moduledoc """
  Use case for checking in multiple children to a session at once.

  ## Business Rules

  - All children must be registered for the session
  - All children must be in :registered status
  - Partial success is allowed (returns successful and failed records)

  ## Events Published

  - `child_checked_in` for each successful check-in
  """

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Shared.DomainEventBus

  @context KlassHero.Participation

  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])

  @session_repository Application.compile_env!(:klass_hero, [:participation, :session_repository])

  @type params :: %{
          required(:record_ids) => [String.t()],
          required(:checked_in_by) => String.t(),
          optional(:notes) => String.t()
        }

  @type result :: %{
          successful: [ParticipationRecord.t()],
          failed: [{String.t(), term()}]
        }

  @doc """
  Checks in multiple children to a session.

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
  @spec execute(params()) :: result()
  def execute(%{record_ids: record_ids, checked_in_by: checked_in_by} = params) do
    notes = Map.get(params, :notes)

    # Trigger: all records in a bulk check-in belong to the same session
    # Why: fetching session once avoids N redundant queries for the same session_id
    # Outcome: session resolved lazily from first successful record, reused for all
    {results, _session} =
      Enum.map_reduce(record_ids, nil, fn record_id, session ->
        case check_in_record(record_id, checked_in_by, notes, session) do
          {:ok, persisted, resolved_session} ->
            {{:ok, persisted}, resolved_session}

          {:error, _, _} = error ->
            {error, session}
        end
      end)

    results
    |> Enum.reduce(%{successful: [], failed: []}, &categorize_result/2)
    |> then(fn result ->
      %{
        successful: Enum.reverse(result.successful),
        failed: Enum.reverse(result.failed)
      }
    end)
  end

  defp check_in_record(record_id, checked_in_by, notes, session) do
    with {:ok, record} <- @participation_repository.get_by_id(record_id),
         {:ok, checked_in} <- ParticipationRecord.check_in(record, checked_in_by, notes),
         {:ok, persisted} <- @participation_repository.update(checked_in),
         {:ok, session} <- resolve_session(session, persisted.session_id) do
      publish_event(persisted, session)
      {:ok, persisted, session}
    else
      {:error, reason} -> {:error, record_id, reason}
    end
  end

  defp resolve_session(%ProgramSession{} = session, _session_id), do: {:ok, session}
  defp resolve_session(nil, session_id), do: @session_repository.get_by_id(session_id)

  defp categorize_result({:ok, record}, acc) do
    %{acc | successful: [record | acc.successful]}
  end

  defp categorize_result({:error, record_id, reason}, acc) do
    %{acc | failed: [{record_id, reason} | acc.failed]}
  end

  defp publish_event(record, session) do
    event = ParticipationEvents.child_checked_in(record, session)
    DomainEventBus.dispatch(@context, event)
  end
end

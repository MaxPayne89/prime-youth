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
  alias KlassHero.Shared.DomainEventBus

  @context KlassHero.Participation

  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])

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

    record_ids
    |> Enum.map(&check_in_record(&1, checked_in_by, notes))
    |> Enum.reduce(%{successful: [], failed: []}, &categorize_result/2)
    |> then(fn result ->
      %{
        successful: Enum.reverse(result.successful),
        failed: Enum.reverse(result.failed)
      }
    end)
  end

  defp check_in_record(record_id, checked_in_by, notes) do
    with {:ok, record} <- @participation_repository.get_by_id(record_id),
         {:ok, checked_in} <- ParticipationRecord.check_in(record, checked_in_by, notes),
         {:ok, persisted} <- @participation_repository.update(checked_in) do
      publish_event(persisted)
      {:ok, persisted}
    else
      {:error, reason} -> {:error, record_id, reason}
    end
  end

  defp categorize_result({:ok, record}, acc) do
    %{acc | successful: [record | acc.successful]}
  end

  defp categorize_result({:error, record_id, reason}, acc) do
    %{acc | failed: [{record_id, reason} | acc.failed]}
  end

  defp publish_event(record) do
    event = ParticipationEvents.child_checked_in(record)
    DomainEventBus.dispatch(@context, event)
  end
end

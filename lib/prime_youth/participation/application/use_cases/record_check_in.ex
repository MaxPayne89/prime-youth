defmodule PrimeYouth.Participation.Application.UseCases.RecordCheckIn do
  @moduledoc """
  Use case for checking in a child to a session.

  ## Business Rules

  - Child must be registered for the session
  - Child must be in :registered status
  - Records who performed the check-in and optional notes

  ## Events Published

  - `child_checked_in` on successful check-in
  """

  alias PrimeYouth.Participation.Domain.Events.ParticipationEvents
  alias PrimeYouth.Participation.Domain.Models.ParticipationRecord
  alias PrimeYouth.Participation.EventPublisher

  @type params :: %{
          required(:record_id) => String.t(),
          required(:checked_in_by) => String.t(),
          optional(:notes) => String.t()
        }

  @type result :: {:ok, ParticipationRecord.t()} | {:error, term()}

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
  @spec execute(params()) :: result()
  def execute(%{record_id: record_id, checked_in_by: checked_in_by} = params) do
    notes = Map.get(params, :notes)

    with {:ok, record} <- participation_repository().get_by_id(record_id),
         {:ok, checked_in} <- ParticipationRecord.check_in(record, checked_in_by, notes),
         {:ok, persisted} <- participation_repository().update(checked_in) do
      publish_event(persisted)
      {:ok, persisted}
    end
  end

  defp publish_event(record) do
    record
    |> ParticipationEvents.child_checked_in()
    |> EventPublisher.publish()
  end

  defp participation_repository do
    Application.get_env(:prime_youth, :participation)[:participation_repository]
  end
end

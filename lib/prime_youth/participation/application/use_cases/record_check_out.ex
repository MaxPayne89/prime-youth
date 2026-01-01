defmodule PrimeYouth.Participation.Application.UseCases.RecordCheckOut do
  @moduledoc """
  Use case for checking out a child from a session.

  ## Business Rules

  - Child must be checked in to the session
  - Child must be in :checked_in status
  - Records who performed the check-out and optional notes

  ## Events Published

  - `child_checked_out` on successful check-out
  """

  alias PrimeYouth.Participation.Domain.Events.ParticipationEvents
  alias PrimeYouth.Participation.Domain.Models.ParticipationRecord
  alias PrimeYouth.Participation.EventPublisher

  @type params :: %{
          required(:record_id) => String.t(),
          required(:checked_out_by) => String.t(),
          optional(:notes) => String.t()
        }

  @type result :: {:ok, ParticipationRecord.t()} | {:error, term()}

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
  @spec execute(params()) :: result()
  def execute(%{record_id: record_id, checked_out_by: checked_out_by} = params) do
    notes = Map.get(params, :notes)

    with {:ok, record} <- participation_repository().get_by_id(record_id),
         {:ok, checked_out} <- ParticipationRecord.check_out(record, checked_out_by, notes),
         {:ok, persisted} <- participation_repository().update(checked_out) do
      publish_event(persisted)
      {:ok, persisted}
    end
  end

  defp publish_event(record) do
    record
    |> ParticipationEvents.child_checked_out()
    |> EventPublisher.publish()
  end

  defp participation_repository do
    Application.get_env(:prime_youth, :participation)[:participation_repository]
  end
end

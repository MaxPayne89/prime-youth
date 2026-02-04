defmodule KlassHero.Participation.Application.UseCases.CompleteSession do
  @moduledoc """
  Use case for completing an in-progress session.

  ## Business Rules

  - Only :in_progress sessions can be completed
  - Session transitions to :completed status
  - Remaining :registered participants are marked as :absent

  ## Events Published

  - `session_completed` on successful completion
  - `child_marked_absent` for each child marked absent
  """

  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Shared.DomainEventBus

  @context KlassHero.Participation

  @session_repository Application.compile_env!(:klass_hero, [:participation, :session_repository])
  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])

  @type result :: {:ok, ProgramSession.t()} | {:error, term()}

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
  @spec execute(String.t()) :: result()
  def execute(session_id) when is_binary(session_id) do
    with {:ok, session} <- @session_repository.get_by_id(session_id),
         {:ok, completed} <- ProgramSession.complete(session),
         {:ok, persisted} <- @session_repository.update(completed),
         :ok <- mark_remaining_as_absent(session_id) do
      publish_session_completed(persisted)
      {:ok, persisted}
    end
  end

  defp mark_remaining_as_absent(session_id) do
    session_id
    |> @participation_repository.list_by_session()
    |> Enum.filter(&(&1.status == :registered))
    |> Enum.each(&mark_absent/1)

    :ok
  end

  defp mark_absent(%ParticipationRecord{} = record) do
    with {:ok, absent} <- ParticipationRecord.mark_absent(record),
         {:ok, persisted} <- @participation_repository.update(absent) do
      publish_child_absent(persisted)
      :ok
    end
  end

  defp publish_session_completed(session) do
    event = ParticipationEvents.session_completed(session)
    DomainEventBus.dispatch(@context, event)
  end

  defp publish_child_absent(record) do
    event = ParticipationEvents.child_marked_absent(record)
    DomainEventBus.dispatch(@context, event)
  end
end

defmodule KlassHero.Participation.Application.UseCases.ReviewBehavioralNote do
  @moduledoc """
  Use case for approving or rejecting a behavioral note.

  ## Business Rules

  - Note must exist
  - Note must be in :pending_approval status
  - Decision must be :approve or :reject
  - Rejection reason is optional

  ## Events Published

  - `behavioral_note_approved` on approval
  - `behavioral_note_rejected` on rejection
  """

  alias KlassHero.Participation.Application.UseCases.Shared
  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.EventPublisher

  @behavioral_note_repository Application.compile_env!(:klass_hero, [
                                :participation,
                                :behavioral_note_repository
                              ])

  @type params :: %{
          required(:note_id) => String.t(),
          required(:parent_id) => String.t(),
          required(:decision) => :approve | :reject,
          optional(:reason) => String.t()
        }

  @type result :: {:ok, BehavioralNote.t()} | {:error, term()}

  @doc """
  Reviews a behavioral note (approve or reject).

  ## Parameters

  - `params` - Map containing:
    - `note_id` - ID of the behavioral note
    - `parent_id` - ID of the parent (ownership enforced at DB level)
    - `decision` - `:approve` or `:reject`
    - `reason` - Optional rejection reason

  ## Returns

  - `{:ok, note}` on success
  - `{:error, :not_found}` if note doesn't exist or doesn't belong to parent
  - `{:error, :invalid_status_transition}` if note not pending
  """
  @spec execute(params()) :: result()
  def execute(%{note_id: note_id, parent_id: parent_id, decision: decision} = params) do
    reason = Map.get(params, :reason)

    # Trigger: scoped query ensures note belongs to this parent
    # Why: DB-enforced ownership — no separate authorization check needed
    # Outcome: returns :not_found if note doesn't belong to parent
    with {:ok, note} <- @behavioral_note_repository.get_by_id_and_parent(note_id, parent_id),
         {:ok, reviewed} <- apply_decision(note, decision, reason),
         {:ok, persisted} <- @behavioral_note_repository.update(reviewed) do
      Shared.log_publish_result(publish_event(persisted, decision), persisted.id)
      {:ok, persisted}
    end
  end

  defp apply_decision(note, :approve, _reason), do: BehavioralNote.approve(note)
  defp apply_decision(note, :reject, reason), do: BehavioralNote.reject(note, reason)
  defp apply_decision(_note, _decision, _reason), do: {:error, :invalid_decision}

  defp publish_event(note, :approve) do
    note
    |> ParticipationEvents.behavioral_note_approved()
    |> EventPublisher.publish()
  end

  defp publish_event(note, :reject) do
    note
    |> ParticipationEvents.behavioral_note_rejected()
    |> EventPublisher.publish()
  end
end

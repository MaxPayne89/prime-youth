defmodule KlassHero.Participation.Application.UseCases.ListPendingBehavioralNotes do
  @moduledoc """
  Use case for listing pending behavioral notes for a parent.

  Returns all notes awaiting the parent's review, ordered by submission date descending.
  """

  alias KlassHero.Participation.Domain.Models.BehavioralNote

  @behavioral_note_repository Application.compile_env!(:klass_hero, [
                                :participation,
                                :behavioral_note_repository
                              ])

  @type result :: {:ok, [BehavioralNote.t()]}

  @doc """
  Lists pending behavioral notes for a parent.

  ## Parameters

  - `parent_id` - ID of the parent

  ## Returns

  `{:ok, notes}` - List of pending behavioral notes.
  """
  @spec execute(String.t()) :: result()
  def execute(parent_id) when is_binary(parent_id) do
    notes = @behavioral_note_repository.list_pending_by_parent(parent_id)
    {:ok, notes}
  end
end

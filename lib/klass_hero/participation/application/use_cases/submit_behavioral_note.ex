defmodule KlassHero.Participation.Application.UseCases.SubmitBehavioralNote do
  @moduledoc """
  Use case for submitting a behavioral note about a child's participation.

  ## Business Rules

  - Participation record must exist
  - Record must be in :checked_in or :checked_out status
  - Content must be non-blank and at most 1000 characters
  - One note per provider per participation record (enforced by unique constraint)
  - Parent ID is resolved from the participation record

  ## Events Published

  - `behavioral_note_submitted` on successful submission
  """

  alias KlassHero.Participation.Application.UseCases.Shared
  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.EventPublisher

  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])
  @behavioral_note_repository Application.compile_env!(:klass_hero, [
                                :participation,
                                :behavioral_note_repository
                              ])

  @type params :: %{
          required(:participation_record_id) => String.t(),
          required(:provider_id) => String.t(),
          required(:content) => String.t()
        }

  @type result :: {:ok, BehavioralNote.t()} | {:error, term()}

  @doc """
  Submits a behavioral note for a participation record.

  ## Parameters

  - `params` - Map containing:
    - `participation_record_id` - ID of the participation record
    - `provider_id` - ID of the provider submitting the note
    - `content` - Note content (max 1000 chars)

  ## Returns

  - `{:ok, note}` on success
  - `{:error, :not_found}` if record doesn't exist
  - `{:error, :invalid_record_status}` if record not checked_in/checked_out
  - `{:error, :blank_content}` if content is blank after normalization
  - `{:error, :duplicate_note}` if provider already submitted a note
  """
  @spec execute(params()) :: result()
  def execute(
        %{participation_record_id: record_id, provider_id: provider_id, content: content} =
          _params
      ) do
    normalized_content = Shared.normalize_notes(content)

    with {:content, content} when content != nil <- {:content, normalized_content},
         {:ok, record} <- @participation_repository.get_by_id(record_id),
         true <- ParticipationRecord.allows_behavioral_note?(record),
         {:ok, note} <- build_note(record, provider_id, content),
         {:ok, persisted} <- @behavioral_note_repository.create(note) do
      Shared.log_publish_result(publish_event(persisted), persisted.id)
      {:ok, persisted}
    else
      # Trigger: content was blank or whitespace-only
      # Why: normalize_notes returns nil for blank strings
      # Outcome: return blank_content error before any DB calls
      {:content, nil} -> {:error, :blank_content}
      # Trigger: record is not in a note-eligible status
      # Why: notes should only be added after the child has been checked in
      # Outcome: blocks note creation for registered/absent records
      false -> {:error, :invalid_record_status}
      error -> error
    end
  end

  defp build_note(record, provider_id, content) do
    BehavioralNote.new(%{
      id: Ecto.UUID.generate(),
      participation_record_id: record.id,
      child_id: record.child_id,
      parent_id: record.parent_id,
      provider_id: provider_id,
      content: content
    })
  end

  defp publish_event(note) do
    note
    |> ParticipationEvents.behavioral_note_submitted()
    |> EventPublisher.publish()
  end
end

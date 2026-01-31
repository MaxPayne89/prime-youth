defmodule KlassHero.Participation.Application.UseCases.ReviseBehavioralNote do
  @moduledoc """
  Use case for revising a rejected behavioral note.

  ## Business Rules

  - Note must exist
  - Note must be in :rejected status
  - New content must be non-blank and at most 1000 characters

  ## Events Published

  - `behavioral_note_submitted` on successful revision (resubmission)
  """

  alias KlassHero.Participation.Application.UseCases.Shared
  alias KlassHero.Participation.Domain.Events.ParticipationEvents
  alias KlassHero.Participation.Domain.Models.BehavioralNote
  alias KlassHero.Participation.EventPublisher

  require Logger

  @type params :: %{
          required(:note_id) => String.t(),
          required(:content) => String.t()
        }

  @type result :: {:ok, BehavioralNote.t()} | {:error, term()}

  @doc """
  Revises a rejected behavioral note with new content.

  ## Parameters

  - `params` - Map containing:
    - `note_id` - ID of the behavioral note
    - `content` - New note content (max 1000 chars)

  ## Returns

  - `{:ok, note}` on success
  - `{:error, :not_found}` if note doesn't exist
  - `{:error, :invalid_status_transition}` if note not rejected
  - `{:error, :blank_content}` if content is blank
  """
  @spec execute(params()) :: result()
  def execute(%{note_id: note_id, content: content}) do
    normalized_content = Shared.normalize_notes(content)

    with {:content, content} when content != nil <- {:content, normalized_content},
         {:ok, note} <- behavioral_note_repository().get_by_id(note_id),
         {:ok, revised} <- BehavioralNote.revise(note, content),
         {:ok, persisted} <- behavioral_note_repository().update(revised) do
      log_publish_result(publish_event(persisted), persisted.id)
      {:ok, persisted}
    else
      {:content, nil} -> {:error, :blank_content}
      error -> error
    end
  end

  defp publish_event(note) do
    note
    |> ParticipationEvents.behavioral_note_submitted()
    |> EventPublisher.publish()
  end

  defp log_publish_result(:ok, _note_id), do: :ok

  defp log_publish_result({:error, reason}, note_id) do
    Logger.warning("[ReviseBehavioralNote] PubSub publish failed",
      note_id: note_id,
      reason: inspect(reason)
    )
  end

  defp behavioral_note_repository do
    Application.get_env(:klass_hero, :participation)[:behavioral_note_repository]
  end
end

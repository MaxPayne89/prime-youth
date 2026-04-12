defmodule KlassHero.Participation.Application.Shared do
  @moduledoc """
  Shared utilities for Participation use cases.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord
  alias KlassHero.Participation.Domain.Models.ProgramSession
  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Participation

  @participation_reader Application.compile_env!(:klass_hero, [
                          :participation,
                          :participation_query_repository
                        ])
  @participation_repository Application.compile_env!(:klass_hero, [
                              :participation,
                              :participation_repository
                            ])

  @session_reader Application.compile_env!(:klass_hero, [:participation, :session_query_repository])

  @doc """
  Normalizes notes by trimming whitespace and converting empty strings to nil.

  ## Examples

      iex> normalize_notes(nil)
      nil

      iex> normalize_notes("  hello  ")
      "hello"

      iex> normalize_notes("   ")
      nil
  """
  @spec normalize_notes(String.t() | nil) :: String.t() | nil
  def normalize_notes(nil), do: nil

  def normalize_notes(notes) when is_binary(notes) do
    case String.trim(notes) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @doc """
  Runs the shared attendance action pipeline: fetch → domain call → persist → fetch session → publish event.

  Accepts the domain function (e.g. `&ParticipationRecord.check_in/3`) and event function
  (e.g. `&ParticipationEvents.child_checked_in/2`) to keep the pipeline generic while each
  use case controls the specific action and event.

  The session is fetched after persisting so the event factory can include `program_id` in
  the payload, enabling provider-specific PubSub topic routing.
  """
  @type domain_fn ::
          (ParticipationRecord.t(), String.t(), String.t() | nil ->
             {:ok, ParticipationRecord.t()} | {:error, term()})
  @type event_fn :: (ParticipationRecord.t(), ProgramSession.t() | nil -> DomainEvent.t())

  @spec run_attendance_action(String.t(), String.t(), String.t() | nil, domain_fn(), event_fn()) ::
          {:ok, ParticipationRecord.t()} | {:error, term()}
  def run_attendance_action(record_id, actor_id, notes, domain_fn, event_fn) do
    notes = normalize_notes(notes)

    with {:ok, record} <- @participation_reader.get_by_id(record_id),
         {:ok, updated} <- domain_fn.(record, actor_id, notes),
         {:ok, persisted} <- @participation_repository.update(updated) do
      # Trigger: session fetch is best-effort for event enrichment
      # Why: the attendance action already succeeded; session fetch failure
      #      should not make the caller see an error
      # Outcome: if session found, event includes program_id; if not, event
      #          still dispatched without it (NotifyLiveViews handles gracefully)
      session =
        case @session_reader.get_by_id(persisted.session_id) do
          {:ok, session} ->
            session

          {:error, reason} ->
            Logger.warning("[Participation.Shared] Session fetch failed for event enrichment",
              session_id: persisted.session_id,
              reason: reason
            )

            nil
        end

      event = event_fn.(persisted, session)
      DomainEventBus.dispatch(@context, event)
      {:ok, persisted}
    end
  end

  @doc """
  Logs the result of a PubSub event publish attempt.

  Silently succeeds on `:ok`, logs a warning on error so callers
  don't need to duplicate logging logic.
  """
  @spec log_publish_result(:ok | {:error, term()}, String.t()) :: :ok
  def log_publish_result(:ok, _note_id), do: :ok

  def log_publish_result({:error, reason}, note_id) do
    Logger.warning("[Participation] PubSub publish failed",
      note_id: note_id,
      reason: inspect(reason)
    )
  end
end

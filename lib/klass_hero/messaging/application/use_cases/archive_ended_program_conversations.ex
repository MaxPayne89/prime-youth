defmodule KlassHero.Messaging.Application.UseCases.ArchiveEndedProgramConversations do
  @moduledoc """
  Use case for archiving conversations associated with programs that have ended.

  This use case:
  1. Calculates the cutoff date based on configuration
  2. Archives all program_broadcast conversations for programs that ended before the cutoff
  3. Publishes a bulk archived event for consistency

  Typically run by a background worker (Oban) on a daily schedule.
  """

  alias KlassHero.Messaging.EventPublisher
  alias KlassHero.Messaging.Repositories

  require Logger

  @doc """
  Archives conversations for programs that ended before the configured cutoff.

  ## Parameters
  - opts: Optional parameters
    - days_after_program_end: Number of days after program end to archive (default from config)

  ## Returns
  - `{:ok, %{count: n, conversation_ids: [ids]}}` - Success with count and IDs
  - `{:error, reason}` - Failure
  """
  @spec execute(keyword()) :: {:ok, %{count: non_neg_integer(), conversation_ids: [String.t()]}}
  def execute(opts \\ []) do
    days = Keyword.get_lazy(opts, :days_after_program_end, &default_days_after_program_end/0)

    cutoff_date =
      Date.utc_today()
      |> Date.add(-days)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Logger.info("Archiving conversations for programs ended before cutoff",
      cutoff_date: cutoff_date,
      days_after_program_end: days
    )

    case Repositories.conversations().archive_ended_program_conversations(cutoff_date) do
      {:ok, %{count: 0} = result} ->
        Logger.debug("No conversations to archive for ended programs")
        {:ok, result}

      {:ok, %{count: count, conversation_ids: ids} = result} ->
        publish_event(ids, count)

        Logger.info("Archived conversations for ended programs",
          count: count,
          cutoff_date: cutoff_date
        )

        {:ok, result}

      {:error, reason} = error ->
        Logger.error("Failed to archive ended program conversations",
          reason: inspect(reason)
        )

        error
    end
  end

  defp publish_event(conversation_ids, count) do
    case EventPublisher.publish_conversations_archived(conversation_ids, :program_ended, count) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish conversations_archived event",
          count: count,
          reason: inspect(reason)
        )

        :ok
    end
  end

  defp default_days_after_program_end do
    Repositories.retention_config()[:days_after_program_end] || 30
  end
end

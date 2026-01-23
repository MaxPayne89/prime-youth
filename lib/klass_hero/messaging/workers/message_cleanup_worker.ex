defmodule KlassHero.Messaging.Workers.MessageCleanupWorker do
  @moduledoc """
  Oban worker that archives conversations for programs that ended more than 30 days ago.

  Scheduled to run daily at 3 AM via Oban cron configuration.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Repo

  require Logger

  @days_after_program_end 30

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    cutoff_date = Date.utc_today() |> Date.add(-@days_after_program_end)

    Logger.info("Starting message cleanup for programs ended before #{cutoff_date}")

    {count, _} = archive_old_program_conversations(cutoff_date)

    Logger.info("Archived #{count} conversations for ended programs")

    :ok
  end

  defp archive_old_program_conversations(cutoff_date) do
    now = DateTime.utc_now()

    from(c in ConversationSchema,
      join: p in assoc(c, :program),
      where: c.type == "program_broadcast",
      where: is_nil(c.archived_at),
      where: not is_nil(p.end_date),
      where: p.end_date < ^cutoff_date
    )
    |> Repo.update_all(set: [archived_at: now, retention_until: DateTime.add(now, 30, :day)])
  end
end

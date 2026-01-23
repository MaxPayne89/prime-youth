defmodule KlassHero.Messaging.Workers.RetentionPolicyWorker do
  @moduledoc """
  Oban worker that permanently deletes messages from conversations
  that have exceeded their retention period.

  Scheduled to run daily at 4 AM via Oban cron configuration.
  This is the final cleanup step after conversations have been archived.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  import Ecto.Query

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSchema
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.MessageSchema
  alias KlassHero.Repo

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()

    Logger.info("Starting retention policy enforcement at #{now}")

    case Repo.transaction(fn ->
           {message_count, _} = delete_expired_messages(now)
           {conversation_count, _} = delete_expired_conversations(now)
           {message_count, conversation_count}
         end) do
      {:ok, {message_count, conversation_count}} ->
        Logger.info(
          "Retention policy complete: deleted #{message_count} messages, #{conversation_count} conversations"
        )

        :ok

      {:error, reason} ->
        Logger.error("Retention policy failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp delete_expired_messages(now) do
    expired_conversation_ids =
      from(c in ConversationSchema,
        where: not is_nil(c.retention_until),
        where: c.retention_until < ^now,
        select: c.id
      )

    from(m in MessageSchema,
      where: m.conversation_id in subquery(expired_conversation_ids)
    )
    |> Repo.delete_all()
  end

  defp delete_expired_conversations(now) do
    from(c in ConversationSchema,
      where: not is_nil(c.retention_until),
      where: c.retention_until < ^now
    )
    |> Repo.delete_all()
  end
end

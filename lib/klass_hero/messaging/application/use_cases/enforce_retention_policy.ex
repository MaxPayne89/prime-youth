defmodule KlassHero.Messaging.Application.UseCases.EnforceRetentionPolicy do
  @moduledoc """
  Use case for enforcing data retention policy on messaging data.

  This use case:
  1. Deletes all messages from conversations that have exceeded their retention period
  2. Deletes the expired conversations themselves
  3. Publishes a retention_enforced event

  Typically run by a background worker (Oban) on a daily schedule after
  the archive worker has run.
  """

  alias KlassHero.Messaging.EventPublisher
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Repo

  require Logger

  @doc """
  Enforces retention policy by deleting expired messages and conversations.

  All operations are performed in a transaction to ensure consistency.

  ## Returns
  - `{:ok, %{messages_deleted: n, conversations_deleted: m}}` - Success
  - `{:error, reason}` - Failure
  """
  @spec execute() ::
          {:ok, %{messages_deleted: non_neg_integer(), conversations_deleted: non_neg_integer()}}
          | {:error, term()}
  def execute do
    now = DateTime.utc_now()
    repos = Repositories.all()

    Logger.info("Enforcing retention policy", timestamp: now)

    case Repo.transaction(fn ->
           with {:ok, msg_count, _conv_ids} <-
                  repos.messages.delete_for_expired_conversations(now),
                {:ok, conv_count} <- repos.conversations.delete_expired(now) do
             %{messages_deleted: msg_count, conversations_deleted: conv_count}
           else
             {:error, reason} -> Repo.rollback(reason)
           end
         end) do
      {:ok, result} ->
        publish_event(result.messages_deleted, result.conversations_deleted)

        Logger.info("Retention policy enforcement complete",
          messages_deleted: result.messages_deleted,
          conversations_deleted: result.conversations_deleted
        )

        {:ok, result}

      {:error, reason} = error ->
        Logger.error("Retention policy enforcement failed",
          reason: inspect(reason)
        )

        error
    end
  end

  defp publish_event(messages_deleted, conversations_deleted) do
    case EventPublisher.publish_retention_enforced(messages_deleted, conversations_deleted) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish retention_enforced event",
          messages_deleted: messages_deleted,
          conversations_deleted: conversations_deleted,
          reason: inspect(reason)
        )

        :ok
    end
  end
end

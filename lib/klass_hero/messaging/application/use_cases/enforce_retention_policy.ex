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

  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Messaging

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

    Logger.info("Enforcing retention policy", timestamp: now)

    now
    |> run_retention_transaction()
    |> handle_result()
  end

  defp run_retention_transaction(now) do
    repos = Repositories.all()

    Repo.transaction(fn ->
      with {:ok, msg_count, _conv_ids} <-
             repos.messages.delete_for_expired_conversations(now),
           {:ok, conv_count} <- repos.conversations.delete_expired(now) do
        %{messages_deleted: msg_count, conversations_deleted: conv_count}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp handle_result({:ok, result}) do
    publish_event(result.messages_deleted, result.conversations_deleted)

    Logger.info("Retention policy enforcement complete",
      messages_deleted: result.messages_deleted,
      conversations_deleted: result.conversations_deleted
    )

    {:ok, result}
  end

  defp handle_result({:error, reason} = error) do
    Logger.error("Retention policy enforcement failed",
      reason: inspect(reason)
    )

    error
  end

  defp publish_event(messages_deleted, conversations_deleted) do
    event = MessagingEvents.retention_enforced(messages_deleted, conversations_deleted)
    DomainEventBus.dispatch(@context, event)
    :ok
  end
end

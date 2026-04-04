defmodule KlassHero.Messaging.Application.UseCases.EnforceRetentionPolicy do
  @moduledoc """
  Use case for enforcing data retention policy on messaging data.

  This use case:
  1. Collects S3 attachment URLs for expired conversations (before DB deletion)
  2. Deletes all messages from conversations that have exceeded their retention period
  3. Deletes the expired conversations themselves (cascade-deletes attachment records)
  4. Cleans up S3 files for the deleted attachments
  5. Publishes a retention_enforced event

  The S3 cleanup must happen AFTER the transaction succeeds, because the attachment
  records are cascade-deleted when messages are removed. We collect URLs before the
  transaction so we don't lose the file references.

  Typically run by a background worker (Oban) on a daily schedule after
  the archive worker has run.
  """

  alias KlassHero.Messaging.Domain.Events.MessagingEvents
  alias KlassHero.Repo
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.Storage

  require Logger

  @context KlassHero.Messaging
  @message_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_messages])
  @conversation_repo Application.compile_env!(:klass_hero, [
                       :messaging,
                       :for_managing_conversations
                     ])
  @attachment_repo Application.compile_env!(:klass_hero, [:messaging, :for_managing_attachments])

  @doc """
  Enforces retention policy by deleting expired messages and conversations.

  S3 attachment files are cleaned up after the transaction succeeds.

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
    # Step 1: Collect S3 URLs before transaction — attachment records will be
    # cascade-deleted when messages are deleted, so we must fetch URLs first.
    file_urls = collect_attachment_urls(now)

    # Step 2: Delete messages and conversations in a transaction.
    result =
      Repo.transaction(fn ->
        with {:ok, msg_count, _conv_ids} <-
               @message_repo.delete_for_expired_conversations(now),
             {:ok, conv_count} <- @conversation_repo.delete_expired(now) do
          %{messages_deleted: msg_count, conversations_deleted: conv_count}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    # Step 3: Clean up S3 files only after the transaction succeeds.
    case result do
      {:ok, _} -> cleanup_s3_files(file_urls)
      _ -> :ok
    end

    result
  end

  defp collect_attachment_urls(now) do
    conversation_ids = @conversation_repo.list_expired_ids(now)

    case @attachment_repo.get_urls_for_conversations(conversation_ids) do
      {:ok, urls} ->
        Logger.debug("Collected S3 URLs for retention cleanup", count: length(urls))
        urls

      {:error, reason} ->
        Logger.error("Failed to collect attachment URLs for retention cleanup — S3 files may be orphaned",
          reason: inspect(reason)
        )

        []
    end
  end

  defp cleanup_s3_files([]), do: :ok

  defp cleanup_s3_files(urls) do
    urls
    |> Task.async_stream(
      fn url ->
        case Storage.delete(:public, url) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to delete S3 file during retention cleanup",
              file_url: url,
              reason: inspect(reason)
            )
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
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

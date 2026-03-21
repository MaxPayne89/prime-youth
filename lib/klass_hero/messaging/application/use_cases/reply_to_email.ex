defmodule KlassHero.Messaging.Application.UseCases.ReplyToEmail do
  @moduledoc """
  Use case for replying to an inbound email.

  Persists the reply record with :sending status and enqueues
  an Oban job for async delivery via Swoosh/Resend.
  """

  alias KlassHero.Messaging.Repositories

  require Logger

  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def execute(email_id, reply_body, sent_by_id, opts \\ []) do
    _ = opts
    email_repo = Repositories.inbound_emails()
    reply_repo = Repositories.email_replies()
    scheduler = Repositories.email_job_scheduler()

    with {:ok, _email} <- email_repo.get_by_id(email_id),
         {:ok, reply} <-
           reply_repo.create(%{
             inbound_email_id: email_id,
             body: reply_body,
             sent_by_id: sent_by_id
           }) do
      case scheduler.schedule_reply_delivery(reply.id) do
        {:ok, _job} ->
          Logger.info("Enqueued reply delivery #{reply.id} for email #{email_id}")

        {:error, reason} ->
          Logger.error("Failed to enqueue reply delivery #{reply.id}: #{inspect(reason)}")
      end

      {:ok, reply}
    end
  end
end

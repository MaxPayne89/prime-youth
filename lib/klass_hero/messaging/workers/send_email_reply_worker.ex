defmodule KlassHero.Messaging.Workers.SendEmailReplyWorker do
  @moduledoc """
  Delivers an email reply via Swoosh/Resend.

  Fetches the EmailReply and associated InboundEmail, builds a Swoosh email
  with proper threading headers, delivers, and updates reply status.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias KlassHero.Messaging.Repositories

  require Logger

  @from Application.compile_env!(:klass_hero, [:mailer_defaults, :from])

  # Trigger: Resend API enforces rate limits
  # Why: default Oban backoff doesn't account for 429 responses — retries
  #      fire too soon and hit the limit again
  # Outcome: rate-limited jobs wait 30s+ before retry; other failures use 10s base
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt, unsaved_error: unsaved_error}) do
    if rate_limit_error?(unsaved_error) do
      trunc(min(30 * :math.pow(2, attempt - 1), 300))
    else
      trunc(min(10 * :math.pow(2, attempt - 1), 120))
    end
  end

  defp rate_limit_error?(%{reason: {429, _}}), do: true
  defp rate_limit_error?(_), do: false

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"reply_id" => reply_id}} = job) do
    reply_repo = Repositories.email_replies()
    email_repo = Repositories.inbound_emails()

    with {:ok, reply} <- reply_repo.get_by_id(reply_id),
         {:ok, email} <- email_repo.get_by_id(reply.inbound_email_id) do
      swoosh_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to(email.from_address)
        |> Swoosh.Email.from(@from)
        |> Swoosh.Email.subject("Re: #{email.subject}")
        |> Swoosh.Email.text_body(reply.body)
        |> maybe_add_threading_headers(email.message_id)

      now = DateTime.utc_now()

      case KlassHero.Mailer.deliver(swoosh_email) do
        {:ok, %{id: resend_id}} ->
          mark_reply_sent(reply_repo, reply_id, %{resend_message_id: resend_id, sent_at: now})
          Logger.info("Delivered reply #{reply_id} to #{email.from_address}")
          :ok

        {:ok, _} ->
          mark_reply_sent(reply_repo, reply_id, %{sent_at: now})
          Logger.info("Delivered reply #{reply_id} to #{email.from_address}")
          :ok

        {:error, reason} ->
          Logger.error("Reply delivery failed for #{reply_id}: #{inspect(reason)}")
          mark_reply_failed_if_final(reply_repo, reply_id, job)
          {:error, reason}
      end
    else
      {:error, :not_found} ->
        Logger.error("Reply or email not found for reply #{reply_id}")
        mark_reply_failed_if_final(reply_repo, reply_id, job)
        {:discard, :not_found}
    end
  end

  # Trigger: email delivered but status update may fail (DB timeout, concurrent delete)
  # Why: email already sent — retrying the job would send duplicates
  # Outcome: log critical if update fails, but don't retry
  defp mark_reply_sent(reply_repo, reply_id, attrs) do
    case reply_repo.update_status(reply_id, "sent", attrs) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.critical(
          "Reply #{reply_id} delivered but status update failed: #{inspect(reason)}"
        )
    end
  end

  defp mark_reply_failed_if_final(reply_repo, reply_id, job) do
    if job.attempt >= job.max_attempts do
      case reply_repo.update_status(reply_id, "failed", %{}) do
        {:ok, _} ->
          Logger.error("Marked reply #{reply_id} as permanently failed")

        {:error, reason} ->
          Logger.error("Failed to mark reply #{reply_id} as failed: #{inspect(reason)}")
      end
    end
  end

  defp maybe_add_threading_headers(email, nil), do: email

  defp maybe_add_threading_headers(email, message_id) do
    email
    |> Swoosh.Email.header("In-Reply-To", message_id)
    |> Swoosh.Email.header("References", message_id)
  end
end

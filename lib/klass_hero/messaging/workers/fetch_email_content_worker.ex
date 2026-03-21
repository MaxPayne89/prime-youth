defmodule KlassHero.Messaging.Workers.FetchEmailContentWorker do
  @moduledoc """
  Fetches inbound email content from Resend's receiving API.

  Triggered after webhook stores email metadata. Updates email with
  body_html, body_text, headers, and sets content_status to fetched/failed.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  alias KlassHero.Messaging.Repositories

  require Logger

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

  defp rate_limit_error?(%{reason: :rate_limited}), do: true
  defp rate_limit_error?(_), do: false

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_id" => email_id, "resend_id" => resend_id}} = job) do
    fetcher = Repositories.email_content_fetcher()
    email_repo = Repositories.inbound_emails()

    case fetcher.fetch_content(resend_id) do
      {:ok, content} ->
        attrs = %{
          body_html: content.html,
          body_text: content.text,
          headers: content.headers,
          content_status: "fetched"
        }

        case email_repo.update_content(email_id, attrs) do
          {:ok, _email} ->
            Logger.info("Fetched content for inbound email #{email_id}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to store content for #{email_id}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning(
          "Content fetch failed for #{email_id} (attempt #{job.attempt}): #{inspect(reason)}"
        )

        if job.attempt >= job.max_attempts do
          case email_repo.update_content(email_id, %{content_status: "failed"}) do
            {:ok, _} ->
              Logger.error("Marked email #{email_id} content as permanently failed")

            {:error, mark_reason} ->
              Logger.error("Failed to mark email #{email_id} as failed: #{inspect(mark_reason)}")
          end
        end

        {:error, reason}
    end
  end
end

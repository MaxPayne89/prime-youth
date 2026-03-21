defmodule KlassHero.Messaging.Application.UseCases.ReceiveInboundEmail do
  @moduledoc """
  Use case for storing an inbound email received via webhook.

  Handles deduplication by resend_id — returns {:ok, :duplicate} for already-stored emails.
  """

  alias KlassHero.Messaging.Repositories

  require Logger

  @spec execute(map()) :: {:ok, struct()} | {:ok, :duplicate} | {:error, term()}
  def execute(attrs) when is_map(attrs) do
    repo = Repositories.inbound_emails()

    # Trigger: same email may arrive multiple times (Resend retries on non-2xx)
    # Why: idempotent handling prevents duplicate storage
    # Outcome: duplicate silently acknowledged, new emails persisted
    case repo.get_by_resend_id(attrs.resend_id) do
      {:ok, _existing} ->
        Logger.debug("Duplicate inbound email ignored: #{attrs.resend_id}")
        {:ok, :duplicate}

      {:error, :not_found} ->
        create_with_race_handling(repo, attrs)
    end
  end

  # Trigger: concurrent webhook deliveries may both pass the dedup check
  # Why: unique_index on resend_id catches the race; treat as duplicate, not failure
  # Outcome: constraint violation returns {:ok, :duplicate} to maintain idempotency
  defp create_with_race_handling(repo, attrs) do
    case repo.create(attrs) do
      {:ok, email} ->
        schedule_content_fetch(email)
        {:ok, email}

      {:error, %Ecto.Changeset{} = changeset} ->
        if unique_constraint_on?(changeset, :resend_id) do
          Logger.debug("Concurrent duplicate inbound email ignored: #{attrs.resend_id}")
          {:ok, :duplicate}
        else
          {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Trigger: email stored successfully with metadata only
  # Why: Resend webhook doesn't include body; content must be fetched via API
  # Outcome: background job enqueued to fetch html, text, and headers
  defp schedule_content_fetch(email) do
    scheduler = Repositories.email_job_scheduler()

    case scheduler.schedule_content_fetch(email.id, email.resend_id) do
      {:ok, _job} ->
        Logger.debug("Enqueued content fetch for email #{email.id}")

      {:error, reason} ->
        Logger.error("Failed to enqueue content fetch for #{email.id}: #{inspect(reason)}")
        Repositories.inbound_emails().update_content(email.id, %{content_status: "failed"})
    end
  end

  defp unique_constraint_on?(%Ecto.Changeset{} = changeset, field) do
    Enum.any?(changeset.errors, fn
      {^field, {_, opts}} -> opts[:constraint] == :unique
      _ -> false
    end)
  end
end

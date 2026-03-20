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
        Logger.debug("Duplicate inbound email ignored", resend_id: attrs.resend_id)
        {:ok, :duplicate}

      {:error, :not_found} ->
        repo.create(attrs)
    end
  end
end

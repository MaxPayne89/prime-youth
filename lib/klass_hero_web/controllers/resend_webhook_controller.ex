defmodule KlassHeroWeb.ResendWebhookController do
  use KlassHeroWeb, :controller

  alias KlassHero.Messaging

  require Logger

  def handle(conn, %{"type" => "email.received", "data" => data}) do
    attrs = %{
      resend_id: data["email_id"],
      from_address: data["from"],
      from_name: data["from_name"],
      to_addresses: data["to"] || [],
      cc_addresses: data["cc"] || [],
      subject: data["subject"] || "(no subject)",
      body_html: data["html"],
      body_text: data["text"],
      headers: data["headers"] || [],
      received_at: parse_timestamp(data["created_at"])
    }

    case Messaging.receive_inbound_email(attrs) do
      {:ok, :duplicate} ->
        json(conn, %{status: "ok", note: "duplicate"})

      {:ok, _email} ->
        json(conn, %{status: "ok"})

      {:error, reason} ->
        Logger.error("Failed to process inbound email #{data["email_id"]}: #{inspect(reason)}")

        # Trigger: processing failed but we still return 200
        # Why: returning non-2xx would cause Resend to retry indefinitely,
        #   potentially flooding the database with bad records
        # Outcome: event acknowledged, error logged for investigation
        json(conn, %{status: "ok"})
    end
  end

  # Trigger: Resend sends events other than email.received (delivered, bounced, etc.)
  # Why: we only care about received emails; returning 200 prevents Resend retries
  # Outcome: event is acknowledged but not processed
  def handle(conn, %{"type" => type}) do
    Logger.debug("Ignoring Resend webhook event", type: type)
    json(conn, %{status: "ok"})
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp_string) do
    case DateTime.from_iso8601(timestamp_string) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> DateTime.utc_now()
    end
  end
end

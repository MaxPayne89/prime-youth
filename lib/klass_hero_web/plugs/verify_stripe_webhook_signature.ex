defmodule KlassHeroWeb.Plugs.VerifyStripeWebhookSignature do
  @moduledoc """
  Verifies Stripe webhook signatures using HMAC-SHA256.

  Stripe signing scheme:
  1. Extract timestamp (t=) and signatures (v1=) from `Stripe-Signature` header
  2. Construct signed payload: "\#{timestamp}.\#{raw_body}"
  3. HMAC-SHA256 with the webhook signing secret (used as raw bytes)
  4. Hex-encode (lowercase) — NOT base64
  5. Compare against all v1= values using a timing-safe compare
  6. Reject if timestamp is older than 5 minutes (replay attack protection)

  Signature verification is skipped in test environments:
  `config :klass_hero, :verify_webhook_signature, false`
  """

  import Plug.Conn

  # 5 minutes in seconds
  @max_timestamp_age 300

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:klass_hero, :verify_webhook_signature, true) do
      verify(conn)
    else
      conn
    end
  end

  defp verify(conn) do
    secret = Application.get_env(:klass_hero, :stripe_webhook_secret)
    raw_body = conn.assigns[:raw_body]
    stripe_sig = get_req_header(conn, "stripe-signature") |> List.first()

    with {:ok, {timestamp, signatures}} <- parse_stripe_signature(stripe_sig),
         {:ok, _} <- validate_timestamp(timestamp),
         {:ok, _} <- validate_signature(secret, raw_body, timestamp, signatures) do
      conn
    else
      {:error, reason} ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: reason})
        |> halt()
    end
  end

  defp parse_stripe_signature(nil), do: {:error, "missing stripe-signature header"}

  defp parse_stripe_signature(header) do
    parts = String.split(header, ",")

    timestamp =
      Enum.find_value(parts, fn part ->
        case String.split(part, "=", parts: 2) do
          ["t", v] -> v
          _ -> nil
        end
      end)

    signatures =
      Enum.flat_map(parts, fn part ->
        case String.split(part, "=", parts: 2) do
          ["v1", v] -> [v]
          _ -> []
        end
      end)

    if timestamp && signatures != [] do
      {:ok, {timestamp, signatures}}
    else
      {:error, "malformed stripe-signature header"}
    end
  end

  defp validate_timestamp(timestamp) do
    case Integer.parse(timestamp) do
      {ts, ""} ->
        now = System.system_time(:second)

        if abs(now - ts) <= @max_timestamp_age do
          {:ok, :valid}
        else
          {:error, "timestamp too old"}
        end

      _ ->
        {:error, "invalid timestamp format"}
    end
  end

  defp validate_signature(secret, raw_body, timestamp, signatures)
       when is_binary(secret) and is_binary(raw_body) do
    signed_payload = "#{timestamp}.#{raw_body}"

    expected =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    if Enum.any?(signatures, &Plug.Crypto.secure_compare(&1, expected)) do
      {:ok, :valid}
    else
      {:error, "invalid signature"}
    end
  end

  defp validate_signature(nil, _raw_body, _timestamp, _signatures),
    do: {:error, "missing stripe webhook secret configuration"}

  defp validate_signature(_secret, nil, _timestamp, _signatures),
    do: {:error, "missing raw body"}
end

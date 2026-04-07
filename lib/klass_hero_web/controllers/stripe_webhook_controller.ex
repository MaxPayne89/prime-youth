defmodule KlassHeroWeb.StripeWebhookController do
  use KlassHeroWeb, :controller

  alias KlassHero.Provider

  require Logger

  @doc """
  Handles Stripe webhook events for Identity Verification.

  Always returns 200 to Stripe — non-2xx responses cause Stripe to retry
  indefinitely, which would flood the system with duplicate events.
  Business errors are logged and discarded.
  """
  def handle(conn, %{
        "type" => "identity.verification_session.verified",
        "data" => %{"object" => object}
      }) do
    session_id = object["id"]
    verified_outputs = object["verified_outputs"]

    case Provider.process_stripe_identity_verification(session_id, :verified, verified_outputs) do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        Logger.warning("Stripe Identity webhook: no provider found for session",
          stripe_session_id: session_id
        )

        json(conn, %{status: "ok"})

      {:error, reason} ->
        Logger.error("Stripe Identity webhook processing failed",
          stripe_session_id: session_id,
          reason: inspect(reason)
        )

        json(conn, %{status: "ok"})
    end
  end

  def handle(conn, %{
        "type" => type,
        "data" => %{"object" => object}
      })
      when type in [
             "identity.verification_session.requires_input",
             "identity.verification_session.canceled"
           ] do
    session_id = object["id"]
    status = if type == "identity.verification_session.requires_input", do: :requires_input, else: :canceled
    Provider.process_stripe_identity_verification(session_id, status, nil)
    json(conn, %{status: "ok"})
  end

  def handle(conn, %{"type" => type}) do
    Logger.debug("Ignoring Stripe webhook event", type: type)
    json(conn, %{status: "ok"})
  end
end

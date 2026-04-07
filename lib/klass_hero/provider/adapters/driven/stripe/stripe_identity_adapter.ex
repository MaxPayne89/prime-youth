defmodule KlassHero.Provider.Adapters.Driven.Stripe.StripeIdentityAdapter do
  @moduledoc """
  Production adapter for the Stripe Identity API.

  Implements the ForCallingStripeIdentity port using Req for HTTP.
  Authentication uses a Bearer token (Stripe secret key).

  Configuration:
  - `:stripe_secret_key` — Stripe secret key (`sk_live_*` / `sk_test_*`)
  - `:stripe_req_options` — Optional Req options (used to inject Req.Test stub in tests)
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForCallingStripeIdentity

  require Logger

  @base_url "https://api.stripe.com/v1"

  @impl true
  def create_verification_session(opts) do
    return_url = Keyword.fetch!(opts, :return_url)

    body = %{
      "type" => "document",
      "options[document][require_live_capture]" => "true",
      "options[document][require_matching_selfie]" => "true",
      "return_url" => return_url
    }

    case req() |> Req.post(url: "/identity/verification_sessions", form: body) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, %{session_id: body["id"], url: body["url"]}}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Stripe Identity create_session failed",
          status: status,
          error: get_in(body, ["error", "message"])
        )

        {:error, {:stripe_error, status, get_in(body, ["error", "message"])}}

      {:error, exception} ->
        Logger.error("Stripe Identity create_session request failed",
          error: inspect(exception)
        )

        {:error, :request_failed}
    end
  end

  @impl true
  def get_verification_session(session_id) when is_binary(session_id) do
    case req() |> Req.get(url: "/identity/verification_sessions/#{session_id}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok,
         %{
           session_id: body["id"],
           status: cast_stripe_status(body["status"]),
           verified_outputs: body["verified_outputs"]
         }}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Stripe Identity get_session failed",
          session_id: session_id,
          status: status,
          error: get_in(body, ["error", "message"])
        )

        {:error, {:stripe_error, status}}

      {:error, exception} ->
        Logger.error("Stripe Identity get_session request failed",
          session_id: session_id,
          error: inspect(exception)
        )

        {:error, :request_failed}
    end
  end

  defp req do
    extra_opts = Application.get_env(:klass_hero, :stripe_req_options, [])
    Req.new([base_url: @base_url, auth: {:bearer, api_key()}] ++ extra_opts)
  end

  defp api_key, do: Application.fetch_env!(:klass_hero, :stripe_secret_key)

  defp cast_stripe_status("verified"), do: :verified
  defp cast_stripe_status("requires_input"), do: :requires_input
  defp cast_stripe_status("canceled"), do: :canceled
  defp cast_stripe_status("processing"), do: :processing
  defp cast_stripe_status(_), do: :created
end

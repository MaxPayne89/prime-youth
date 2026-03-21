defmodule KlassHero.Messaging.Adapters.Driven.ResendEmailContentAdapter do
  @moduledoc """
  Fetches inbound email content from Resend's receiving API.

  Implements ForFetchingEmailContent port using Req HTTP client.
  Endpoint: GET https://api.resend.com/emails/receiving/{id}
  """

  @behaviour KlassHero.Messaging.Domain.Ports.ForFetchingEmailContent

  require Logger

  @base_url "https://api.resend.com"

  @impl true
  def fetch_content(resend_email_id) do
    req = Req.new(base_url: @base_url, auth: {:bearer, api_key()})

    # Trigger: Req.Test plug must only be active in test environment
    # Why: Req.Test raises if no stub is registered, which would break production
    # Outcome: test env uses stubs, prod env makes real HTTP calls
    req =
      if Application.get_env(:klass_hero, :env) == :test do
        Req.merge(req, plug: {Req.Test, __MODULE__})
      else
        req
      end

    case Req.get(req, url: "/emails/receiving/#{resend_email_id}") do
      {:ok, %Req.Response{status: 200, body: body}} ->
        headers = normalize_headers(body["headers"])
        {:ok, %{html: body["html"], text: body["text"], headers: headers}}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status}} when status >= 500 ->
        Logger.error("Resend API server error #{status} for email #{resend_email_id}")
        {:error, :server_error}

      {:error, exception} ->
        Logger.error(
          "Resend API request failed for email #{resend_email_id}: #{inspect(exception)}"
        )

        {:error, :timeout}
    end
  end

  defp normalize_headers(nil), do: []
  defp normalize_headers(headers) when is_list(headers), do: headers

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {name, value} -> %{"name" => name, "value" => value} end)
  end

  defp api_key do
    # Trigger: test environment uses Req.Test stubs and never makes real HTTP calls
    # Why: the Mailer adapter in test is Swoosh.Adapters.Test, which has no :api_key,
    #      so we avoid raising on a missing key that isn't needed in tests
    # Outcome: a placeholder is used in tests; production requires a real key
    if Application.get_env(:klass_hero, :env) == :test do
      "test-api-key"
    else
      Application.get_env(:klass_hero, KlassHero.Mailer)[:api_key] ||
        raise "RESEND_API_KEY not configured"
    end
  end
end

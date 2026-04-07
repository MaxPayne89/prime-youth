defmodule KlassHero.Provider.Adapters.Driven.Stripe.StubStripeIdentityAdapter do
  @moduledoc """
  Test stub for the Stripe Identity port.

  Returns predictable responses. Individual tests can override behaviour using Mimic.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForCallingStripeIdentity

  @stub_session_id "vs_test_stub_0000000000000000"

  @impl true
  def create_verification_session(_opts) do
    {:ok,
     %{
       session_id: @stub_session_id,
       url: "https://verify.stripe.com/start/test#stub"
     }}
  end

  @impl true
  def get_verification_session(@stub_session_id) do
    {:ok,
     %{
       session_id: @stub_session_id,
       status: :verified,
       verified_outputs: %{
         "dob" => %{"year" => 1990, "month" => 6, "day" => 15}
       }
     }}
  end

  def get_verification_session(_session_id), do: {:error, :not_found}
end

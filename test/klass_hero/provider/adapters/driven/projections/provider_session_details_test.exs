defmodule KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetailsTest do
  use KlassHero.DataCase, async: false

  alias KlassHero.Provider.Adapters.Driven.Projections.ProviderSessionDetails

  setup do
    start_supervised!({ProviderSessionDetails, name: :test_provider_session_details})
    :ok
  end

  test "starts and responds to a ping call" do
    assert Process.whereis(:test_provider_session_details) |> is_pid()
  end
end

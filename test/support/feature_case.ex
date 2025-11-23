defmodule PrimeYouthWeb.FeatureCase do
  @moduledoc """
  This module defines the test case to be used by
  feature tests using phoenix_test.

  Feature tests use a user-centric approach to testing,
  focusing on interactions from the user's perspective.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use PrimeYouthWeb.ConnCase

      import PhoenixTest

      # Import helpers for feature testing
      import PrimeYouth.AccountsFixtures
      import PrimeYouth.Factory
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

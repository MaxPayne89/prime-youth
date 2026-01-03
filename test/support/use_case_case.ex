defmodule KlassHero.UseCaseCase do
  @moduledoc """
  This module defines the test case to be used by
  tests for domain use cases.

  Such tests rely on mocking ports and testing business logic
  in isolation from infrastructure concerns.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import KlassHero.UseCaseCase
      import Mox

      # Make the code testable without requiring real adapters
      setup :verify_on_exit!
    end
  end

  setup tags do
    KlassHero.DataCase.setup_sandbox(tags)
    :ok
  end
end

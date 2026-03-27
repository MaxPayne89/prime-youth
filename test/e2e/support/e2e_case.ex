defmodule KlassHeroWeb.E2ECase do
  @moduledoc """
  ExUnit.CaseTemplate for browser-driven E2E tests using Wallaby.

  Handles:
  - Starting Wallaby (once per test module, lazily)
  - Ecto sandbox ownership with metadata for the sandbox plug
  - Common imports (Wallaby.DSL, factories, fixtures, helpers)

  All tests using this case are tagged `@moduletag :e2e` and excluded
  from regular `mix test` runs. Run with `mix test.e2e`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL

      import KlassHero.AccountsFixtures
      import KlassHero.Factory
      import KlassHeroWeb.E2E.MessagingHelpers

      @moduletag :e2e
    end
  end

  setup_all _context do
    {:ok, _} = Application.ensure_all_started(:wallaby)
    :ok
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(KlassHero.Repo, shared: not tags[:async])

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(KlassHero.Repo, pid)

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, sandbox_metadata: metadata}
  end
end

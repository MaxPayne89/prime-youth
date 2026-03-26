ExUnit.start(exclude: [:integration, :e2e], capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(KlassHero.Repo, :manual)

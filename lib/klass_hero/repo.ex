defmodule KlassHero.Repo do
  use Ecto.Repo,
    otp_app: :klass_hero,
    adapter: Ecto.Adapters.Postgres
end

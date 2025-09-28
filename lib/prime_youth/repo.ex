defmodule PrimeYouth.Repo do
  use Ecto.Repo,
    otp_app: :prime_youth,
    adapter: Ecto.Adapters.Postgres
end

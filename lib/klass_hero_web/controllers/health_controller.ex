defmodule KlassHeroWeb.HealthController do
  use KlassHeroWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end

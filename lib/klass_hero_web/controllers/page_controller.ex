defmodule KlassHeroWeb.PageController do
  use KlassHeroWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

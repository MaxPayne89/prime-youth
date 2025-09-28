defmodule PrimeYouthWeb.PageController do
  use PrimeYouthWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

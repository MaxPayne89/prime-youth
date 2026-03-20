defmodule KlassHeroWeb.Plugs.CacheRawBody do
  @moduledoc """
  Caches the raw request body for webhook signature verification.

  Used as a custom body reader for Plug.Parsers.
  Stores the raw body in conn.assigns[:raw_body].
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end

defmodule PrimeYouthWeb.PageControllerTest do
  use PrimeYouthWeb.ConnCase, async: true

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Prime Youth"
  end
end

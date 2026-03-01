defmodule KlassHeroWeb.Provider.EnrollmentImportTemplateTest do
  use KlassHeroWeb.ConnCase, async: true

  describe "GET /downloads/enrollment-import-template.csv" do
    test "serves the CSV template file", %{conn: conn} do
      conn = get(conn, "/downloads/enrollment-import-template.csv")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "text/csv"
      assert conn.resp_body =~ "Participant information: First name"
    end
  end
end

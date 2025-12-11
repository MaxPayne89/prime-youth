defmodule PrimeYouthWeb.UserDataExportController do
  @moduledoc """
  Controller for GDPR data export functionality.

  Allows authenticated users to download all their personal data as JSON.
  """
  use PrimeYouthWeb, :controller

  alias PrimeYouth.Accounts

  def export(conn, _params) do
    user = conn.assigns.current_scope.user
    data = Accounts.export_user_data(user)
    json_data = Jason.encode!(data, pretty: true)

    filename = "prime_youth_data_export_#{Date.utc_today()}.json"

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, json_data)
  end
end

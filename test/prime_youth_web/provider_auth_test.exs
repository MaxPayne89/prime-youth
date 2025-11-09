defmodule PrimeYouthWeb.ProviderAuthTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PrimeYouth.Accounts
  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Provider
  alias PrimeYouth.Repo

  setup do
    # Create a test user
    {:ok, user} =
      Accounts.register_user(%{
        name: "Test Provider User",
        email: "provider@example.com",
        password: "password123password123"
      })

    %{user: user}
  end

  describe "require_provider on_mount hook" do
    test "redirects to home when user has no provider account", %{conn: conn, user: user} do
      # Log in the user
      conn = log_in_user(conn, user)

      # Try to access a provider route
      {:error, {:redirect, %{to: "/"}}} =
        live(conn, "/provider/dashboard")
    end

    test "assigns current_provider when user has provider account", %{conn: conn, user: user} do
      # Create a provider for this user
      _provider =
        %Provider{}
        |> Provider.changeset(%{
          name: "Test Provider",
          email: "provider@example.com",
          user_id: user.id
        })
        |> Repo.insert!()

      # Log in the user
      conn = log_in_user(conn, user)

      # Access provider route - should succeed and load the dashboard
      assert {:ok, _view, html} = live(conn, "/provider/dashboard")

      # Verify the dashboard loaded (contains provider-specific content)
      assert html =~ "My Programs"
    end
  end
end

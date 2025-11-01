defmodule PrimeYouthWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PrimeYouthWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use PrimeYouthWeb, :verified_routes

      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn
      import PrimeYouthWeb.ConnCase
      # The default endpoint for testing
      @endpoint PrimeYouthWeb.Endpoint

      # Import conveniences for testing with connections
    end
  end

  setup tags do
    PrimeYouth.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Asserts that a LiveView has a flash message of the given kind.

  ## Examples

      assert_flash(lv, :info, "Success")
      assert_flash(lv, :error, ~r/Invalid/)
  """
  def assert_flash(lv, kind, expected) do
    flash = :sys.get_state(lv.pid).socket.assigns.flash

    actual = Phoenix.Flash.get(flash, kind)

    cond do
      is_nil(actual) ->
        flunk(
          "Expected flash #{inspect(kind)} to be set, but it was nil. Flash: #{inspect(flash)}"
        )

      is_binary(expected) and actual == expected ->
        true

      is_struct(expected, Regex) and actual =~ expected ->
        true

      is_binary(expected) ->
        flunk("""
        Expected flash #{inspect(kind)} to equal:
          #{inspect(expected)}
        but got:
          #{inspect(actual)}
        """)

      true ->
        flunk("""
        Expected flash #{inspect(kind)} to match:
          #{inspect(expected)}
        but got:
          #{inspect(actual)}
        """)
    end
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = PrimeYouth.AccountsFixtures.user_fixture()
    scope = PrimeYouth.Accounts.Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = PrimeYouth.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    PrimeYouth.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end

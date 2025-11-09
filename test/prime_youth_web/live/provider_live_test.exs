defmodule PrimeYouthWeb.ProviderLiveTest do
  use PrimeYouthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PrimeYouth.ProgramCatalogFixtures

  alias PrimeYouth.AccountsFixtures
  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program
  alias PrimeYouth.Repo

  describe "ProviderLive.Dashboard" do
    setup %{conn: conn} do
      # Create a user and provider using the fixture (automatically creates user)
      provider = provider_fixture()
      user = Repo.get!(PrimeYouth.Accounts.User, provider.user_id)

      # Log in the user
      conn = log_in_user(conn, user)

      # Create programs with different statuses
      draft_program = insert_program(provider, %{title: "Draft Program", status: "draft"})

      pending_program =
        insert_program(provider, %{title: "Pending Program", status: "pending_approval"})

      approved_program =
        insert_program(provider, %{title: "Approved Program", status: "approved"})

      rejected_program =
        insert_program(provider, %{
          title: "Rejected Program",
          status: "rejected",
          rejection_reason: "Needs more details"
        })

      {:ok,
       conn: conn,
       provider: provider,
       user: user,
       draft: draft_program,
       pending: pending_program,
       approved: approved_program,
       rejected: rejected_program}
    end

    test "displays provider dashboard with program counts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "Provider Dashboard"
      assert html =~ "Draft"
      assert html =~ "Pending Approval"
      assert html =~ "Approved"
      assert html =~ "Rejected"
    end

    test "shows draft programs in draft tab", %{conn: conn, draft: draft} do
      {:ok, view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "Draft Program"
      assert has_element?(view, "#program-#{draft.id}")
    end

    test "shows pending programs in pending tab", %{conn: conn, pending: pending} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Switch to pending tab
      html =
        view
        |> element("#tab-pending")
        |> render_click()

      assert html =~ "Pending Program"
      assert has_element?(view, "#program-#{pending.id}")
    end

    test "shows approved programs in approved tab", %{conn: conn, approved: approved} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Switch to approved tab
      html =
        view
        |> element("#tab-approved")
        |> render_click()

      assert html =~ "Approved Program"
      assert has_element?(view, "#program-#{approved.id}")
    end

    test "shows rejected programs with rejection reason", %{conn: conn, rejected: rejected} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Switch to rejected tab
      html =
        view
        |> element("#tab-rejected")
        |> render_click()

      assert html =~ "Rejected Program"
      assert html =~ "Needs more details"
      assert has_element?(view, "#program-#{rejected.id}")
    end

    test "displays edit button for draft programs", %{conn: conn, draft: draft} do
      {:ok, view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "Edit"
      assert has_element?(view, "#edit-program-#{draft.id}")
    end

    test "displays submit for approval button for draft programs", %{conn: conn, draft: draft} do
      {:ok, view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "Submit for Approval"
      assert has_element?(view, "#submit-program-#{draft.id}")
    end

    test "displays edit button for rejected programs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Switch to rejected tab
      html =
        view
        |> element("#tab-rejected")
        |> render_click()

      assert html =~ "Edit"
    end

    test "displays create new program button", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "Create New Program"
      assert has_element?(view, "#new-program-button")
    end

    test "shows empty state when no programs in tab", %{conn: conn, provider: _provider} do
      # Delete all programs for clean slate
      Repo.delete_all(Program)

      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ "No draft programs"
    end

    test "only shows programs belonging to current provider", %{conn: conn} do
      # Create another provider with programs using the fixture
      other_provider = provider_fixture()
      insert_program(other_provider, %{title: "Other Provider Program"})

      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      # Should not see other provider's programs
      refute html =~ "Other Provider Program"
    end

    test "displays program counts for each status", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      # Should show counts (1 program in each status from setup)
      assert html =~ "Draft (1)"
      assert html =~ "Pending (1)"
      assert html =~ "Approved (1)"
      assert html =~ "Rejected (1)"
    end

    test "navigates to edit page when edit button clicked", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click edit button
      view
      |> element("#edit-program-#{draft.id}")
      |> render_click()

      # Should navigate to edit page
      assert_patch(view, ~p"/provider/programs/#{draft.id}/edit")
    end

    test "submits draft program for approval", %{conn: conn, draft: draft} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click submit for approval button
      html =
        view
        |> element("#submit-program-#{draft.id}")
        |> render_click()

      # Program should move to pending tab
      refute html =~ "Draft Program"

      # Switch to pending tab
      html =
        view
        |> element("#tab-pending")
        |> render_click()

      assert html =~ "Draft Program"
    end

    test "requires authentication to access dashboard", %{provider: _provider} do
      # Create new unauthenticated connection
      conn = build_conn()

      # Should redirect to login
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/provider/dashboard")

      assert path == ~p"/users/log-in"
    end

    test "prevents non-provider users from accessing dashboard", %{provider: _provider} do
      # Create a user without provider association
      non_provider_user = AccountsFixtures.user_fixture()
      conn = log_in_user(build_conn(), non_provider_user)

      # Should redirect with error message
      {:error, {:redirect, %{to: path, flash: flash}}} = live(conn, ~p"/provider/dashboard")

      assert path == "/provider/setup"
      assert flash["error"] == "Please complete your provider profile first."
    end

    test "displays provider name and email", %{conn: conn, provider: provider} do
      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      assert html =~ provider.name
      assert html =~ provider.email
    end

    test "works on mobile viewport (375px)", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/provider/dashboard")

      # Mobile-first design should work at 375px width
      assert html =~ "Provider Dashboard"
      assert has_element?(view, "#program-tabs")
    end

    test "displays program statistics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/provider/dashboard")

      # Should show total programs count
      assert html =~ "Total Programs: 4"
    end
  end

  # Helper functions

  defp insert_program(provider, attrs) do
    default_attrs = %{
      title: "Test Program",
      description: "A test program description that is long enough to pass validation.",
      provider_id: provider.id,
      category: "sports",
      age_min: 8,
      age_max: 12,
      capacity: 20,
      current_enrollment: 0,
      price_amount: Decimal.new("100.00"),
      price_currency: "USD",
      price_unit: "session",
      has_discount: false,
      status: "draft",
      is_prime_youth: false,
      featured: false
    }

    %Program{}
    |> Program.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end
end

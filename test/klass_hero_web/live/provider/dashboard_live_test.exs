defmodule KlassHeroWeb.Provider.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.ProviderFixtures

  setup :register_and_log_in_provider

  describe "overview section" do
    test "renders dashboard with business name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify main heading is present (business name + Dashboard)
      assert has_element?(view, "h1")
      # Verify navigation tabs are present
      assert has_element?(view, "nav")
    end

    test "displays stat cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify stat card grid is present (4 stat cards in overview)
      assert has_element?(view, ".grid")
    end

    test "displays business profile card", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Verify business profile section exists with Edit Profile link
      assert has_element?(view, "a", "Edit Profile")
    end

    test "displays business logo when logo_url is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Factory sets logo_url by default, so real logo image should show
      assert has_element?(view, "#business-logo")
      refute has_element?(view, "#business-logo-placeholder")
    end

    test "displays initials placeholder when no logo_url", %{conn: conn, provider: provider} do
      # Remove logo_url from the provider
      provider
      |> Ecto.Changeset.change(logo_url: nil)
      |> KlassHero.Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, "#business-logo-placeholder")
      refute has_element?(view, "#business-logo")
    end

    test "shows 'Not Verified' status when no documents submitted", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, "#verification-status", "Not Verified")
    end

    test "shows 'Pending Review' status when documents are pending", %{
      conn: conn,
      provider: provider
    } do
      KlassHero.Factory.insert(:verification_document_schema,
        provider_id: provider.id,
        document_type: "business_registration",
        status: "pending"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, "#verification-status", "Pending Review")
    end

    test "shows 'Verified' status when provider is verified", %{conn: conn, provider: provider} do
      provider
      |> Ecto.Changeset.change(
        verified: true,
        verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )
      |> KlassHero.Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, "#verification-status", "Verified")
      refute has_element?(view, "#verification-status", "Not Verified")
    end
  end

  describe "new program button gating" do
    test "disables 'New Program' button when provider is not verified", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      assert has_element?(view, "#new-program-btn[disabled]")
      assert has_element?(view, "#new-program-tooltip")
    end

    test "enables 'New Program' button when provider is verified", %{
      conn: conn,
      provider: provider
    } do
      provider
      |> Ecto.Changeset.change(
        verified: true,
        verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )
      |> KlassHero.Repo.update!()

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      refute has_element?(view, "#new-program-btn[disabled]")
      refute has_element?(view, "#new-program-tooltip")
    end

    test "shows tooltip explaining verification requirement", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      html = render(view)
      assert html =~ "Complete business verification to create programs."
    end
  end

  describe "tab navigation" do
    test "navigates to team section via tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click on Team & Profiles tab
      view |> element("a", "Team & Profiles") |> render_click()

      # Verify URL has patched to team section
      assert_patch(view, ~p"/provider/dashboard/team")
    end

    test "navigates to programs section via tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard")

      # Click on My Programs tab
      view |> element("a", "My Programs") |> render_click()

      # Verify URL has patched to programs section
      assert_patch(view, ~p"/provider/dashboard/programs")
    end
  end

  describe "team section" do
    test "renders team section with team members", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      # Verify Add Team Member button is present
      assert has_element?(view, "button", "Add Team Member")
    end
  end

  describe "programs section" do
    test "renders programs section with table", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # Verify programs table exists
      assert has_element?(view, "table")
      # Verify search input exists
      assert has_element?(view, "input[name=\"search\"]")
      # Verify staff filter exists
      assert has_element?(view, "select[name=\"staff_filter\"]")
    end

    test "programs visible after navigating from team tab", %{conn: conn, provider: provider} do
      KlassHero.Factory.insert(:program_schema,
        title: "Soccer Academy",
        category: "sports",
        provider_id: provider.id
      )

      # Mount on team tab first
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      # Navigate to programs tab
      view |> element("a", "My Programs") |> render_click()
      assert_patch(view, ~p"/provider/dashboard/programs")

      assert has_element?(view, "td", "Soccer Academy")
    end

    test "staff filter shows staff members after tab navigation", %{
      conn: conn,
      provider: provider
    } do
      ProviderFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Alice",
        last_name: "Smith"
      )

      # Mount on team tab first
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      # Navigate to programs tab
      view |> element("a", "My Programs") |> render_click()
      assert_patch(view, ~p"/provider/dashboard/programs")

      # Staff filter dropdown should include the staff member
      assert render(view) =~ "Alice Smith"
    end

    test "filters programs by search query", %{conn: conn, provider: provider} do
      # Create programs for this provider
      KlassHero.Factory.insert(:program_schema,
        title: "Soccer Academy",
        category: "sports",
        provider_id: provider.id
      )

      KlassHero.Factory.insert(:program_schema,
        title: "Art Class",
        category: "arts",
        provider_id: provider.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # Search for "Soccer" which should match "Soccer Academy"
      view |> render_change("search_programs", %{"search" => "Soccer"})

      # Verify filtered result is present
      assert has_element?(view, "td", "Soccer Academy")
      # Art Class should not be shown
      refute has_element?(view, "td", "Art Class")
    end

    test "shows empty state when provider has no programs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      # The provider was just created and has no programs
      # Table should exist but be empty (header row only)
      assert has_element?(view, "table")
    end
  end

  describe "roster modal with tabs" do
    setup %{provider: provider} do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          title: "Test Program"
        )

      %{program: program}
    end

    test "shows enrolled and invites tabs when roster opened", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()

      assert has_element?(view, "#roster-modal")
      assert has_element?(view, "#roster-tab-enrolled")
      assert has_element?(view, "#roster-tab-invites")
    end

    test "enrolled tab is active by default", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()

      assert has_element?(view, "#roster-tab-enrolled[aria-selected=true]")
    end

    test "switches to invites tab", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "#roster-tab-invites[aria-selected=true]")
      assert has_element?(view, "#invites-tab-content")
    end

    test "invites tab shows empty state when no invites", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "#invites-empty")
    end
  end

  describe "invites tab content" do
    setup %{provider: provider} do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          title: "Test Program"
        )

      {:ok, _count} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "parent@test.com"
          }
        ])

      %{program: program}
    end

    test "shows invite rows with child name, email, status", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "#invites-table")
      html = render(view)
      assert html =~ "Jane"
      assert html =~ "Smith"
      assert html =~ "parent@test.com"
    end

    test "shows resend button for pending invite", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "[phx-click=resend_invite]")
    end

    test "shows remove button for pending invite", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "[phx-click=delete_invite]")
    end
  end

  describe "invite actions" do
    setup %{provider: provider} do
      program =
        KlassHero.Factory.insert(:program_schema,
          provider_id: provider.id,
          title: "Test Program"
        )

      {:ok, _count} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "parent@test.com"
          }
        ])

      %{program: program}
    end

    test "resend invite shows success flash", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      html = view |> element("[phx-click=resend_invite]") |> render_click()

      assert html =~ "Invite resent"
    end

    test "delete invite removes row from table", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      assert has_element?(view, "#invites-table")

      view |> element("[phx-click=delete_invite]") |> render_click()

      assert has_element?(view, "#invites-empty")
    end
  end
end

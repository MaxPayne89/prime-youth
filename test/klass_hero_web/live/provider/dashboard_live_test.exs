defmodule KlassHeroWeb.Provider.DashboardLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Repositories.BulkEnrollmentInviteRepository
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProviderFixtures

  setup :register_and_log_in_provider

  # Trigger: dashboard reads programs from program_listings (CQRS read model)
  # Why: write-side program_schema alone won't appear in the programs tab
  # Outcome: inserts into both programs (for FK constraints) and program_listings (for display)
  defp insert_program_with_listing(attrs) do
    program = KlassHero.Factory.insert(:program_schema, attrs)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %ProgramListingSchema{}
    |> Ecto.Changeset.change(%{
      id: program.id,
      title: program.title,
      description: program.description,
      category: program.category,
      age_range: program.age_range,
      price: program.price,
      pricing_period: program.pricing_period,
      location: program.location,
      cover_image_url: program.cover_image_url,
      icon_path: program.icon_path,
      instructor_name: program.instructor_name,
      instructor_headshot_url: program.instructor_headshot_url,
      start_date: program.start_date,
      end_date: program.end_date,
      meeting_days: program.meeting_days || [],
      meeting_start_time: program.meeting_start_time,
      meeting_end_time: program.meeting_end_time,
      season: program.season,
      registration_start_date: program.registration_start_date,
      registration_end_date: program.registration_end_date,
      provider_id: program.provider_id,
      provider_verified: false,
      inserted_at: program.inserted_at || now,
      updated_at: program.updated_at || now
    })
    |> KlassHero.Repo.insert!()

    program
  end

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
      insert_program_with_listing(
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
      insert_program_with_listing(
        title: "Soccer Academy",
        category: "sports",
        provider_id: provider.id
      )

      insert_program_with_listing(
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
        insert_program_with_listing(
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
        insert_program_with_listing(
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
        insert_program_with_listing(
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

  # ===========================================================================
  # T3: close_roster handler
  # ===========================================================================

  describe "close roster" do
    setup %{provider: provider} do
      program =
        insert_program_with_listing(
          provider_id: provider.id,
          title: "Test Program"
        )

      %{program: program}
    end

    test "closing roster hides modal", %{conn: conn, program: program} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#view-roster-#{program.id}") |> render_click()
      assert has_element?(view, "#roster-modal")

      view |> element("button[phx-click=close_roster]") |> render_click()
      refute has_element?(view, "#roster-modal")
    end
  end

  # ===========================================================================
  # T4/T6: invite error paths
  # ===========================================================================

  describe "invite error paths" do
    setup %{provider: provider} do
      program =
        insert_program_with_listing(
          provider_id: provider.id,
          title: "Test Program"
        )

      %{program: program}
    end

    test "enrolled invite does not show action buttons", %{
      conn: conn,
      provider: provider,
      program: program
    } do
      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "enrolled@test.com"
          }
        ])

      # Walk through the state machine to enrolled
      [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)

      {:ok, sent} =
        BulkEnrollmentInviteRepository.transition_status(invite, %{
          status: "invite_sent",
          invite_token: "tok",
          invite_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, registered} =
        BulkEnrollmentInviteRepository.transition_status(sent, %{
          status: "registered",
          registered_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, _enrolled} =
        BulkEnrollmentInviteRepository.transition_status(registered, %{
          status: "enrolled",
          enrolled_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      refute has_element?(view, "[phx-click=resend_invite]")
      refute has_element?(view, "[phx-click=delete_invite]")
    end

    test "resend shows error when invite deleted concurrently", %{
      conn: conn,
      provider: provider,
      program: program
    } do
      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "concurrent@test.com"
          }
        ])

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      # Delete the invite from the DB while the DOM still has the button
      [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)
      :ok = BulkEnrollmentInviteRepository.delete(invite.id)

      view |> element("[phx-click=resend_invite]") |> render_click()

      assert_flash(view, :error, "Failed to resend invite.")
    end

    test "delete shows error when invite already removed", %{
      conn: conn,
      provider: provider,
      program: program
    } do
      {:ok, _} =
        BulkEnrollmentInviteRepository.create_batch([
          %{
            program_id: program.id,
            provider_id: provider.id,
            child_first_name: "Jane",
            child_last_name: "Smith",
            child_date_of_birth: ~D[2015-06-15],
            guardian_email: "removed@test.com"
          }
        ])

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()

      # Delete the invite from DB while the DOM still shows it
      [invite] = BulkEnrollmentInviteRepository.list_by_program(program.id)
      :ok = BulkEnrollmentInviteRepository.delete(invite.id)

      view |> element("[phx-click=delete_invite]") |> render_click()

      assert_flash(view, :error, "Invite not found.")
    end
  end

  # ===========================================================================
  # T1/T2: CSV import handler + error rendering
  # ===========================================================================

  describe "CSV import" do
    @csv_defaults %{
      first: "Alice",
      last: "Smith",
      dob: "1/1/2016",
      parent_first: "Bob",
      parent_last: "Smith",
      email: "parent@example.com",
      parent2_first: "",
      parent2_last: "",
      parent2_email: "",
      grade: "",
      school: "",
      has_medical: "",
      medical: "",
      nut_allergy: "",
      photo_marketing: "",
      photo_social: "",
      program: "Ballsports & Parkour",
      instructor: "",
      season: "Test Season"
    }

    @csv_field_order ~w(first last dob parent_first parent_last email
      parent2_first parent2_last parent2_email grade school has_medical
      medical nut_allergy photo_marketing photo_social program instructor season)a

    @csv_header_row [
      "Participant information: First name",
      "Participant information: Last name",
      "Participant information: Date of birth",
      "Parent/guardian information: First name",
      "Parent/guardian information: Last name",
      "Parent/guardian information: Email address",
      "Parent/guardian 2 information: First name",
      "Parent/guardian 2 information: Last name",
      "Parent/guardian 2 information: Email address",
      "School information: Grade",
      "School information: Name",
      "Medical/allergy information: Do you have medical conditions and special needs?",
      "Medical/allergy information: Medical conditions and special needs",
      "Medical/allergy information: Nut allergy",
      ~s|Photography/video release permission: I agree that photos showing my child at camp may appear in marketing materials (e.g. posters, website) free of charge. this agreement is valid for unlimited time for all types of existing media and those that may be created.|,
      ~s|Photography/video release permission: I agree that photos and films showing my child participating in activities may appear for marketing purposes on prime youth's social media channels (e.g. facebook, instagram, youtube) free of charge, valid for unlimited time and without revealing my children's identity.|,
      "Program",
      "Instructor",
      "Season"
    ]

    setup %{provider: provider} do
      program =
        insert_program_with_listing(
          provider_id: provider.id,
          title: "Ballsports & Parkour"
        )

      %{program: program}
    end

    defp build_csv(rows) do
      headers = Enum.map_join(@csv_header_row, ",", &csv_escape/1)

      data_rows =
        Enum.map(rows, fn row ->
          merged = Map.merge(@csv_defaults, row)
          Enum.map_join(@csv_field_order, ",", &csv_escape(merged[&1]))
        end)

      [headers | data_rows] |> Enum.join("\n")
    end

    defp csv_escape(value) when is_binary(value) do
      if String.contains?(value, [",", "\"", "\n"]) do
        "\"" <> String.replace(value, "\"", "\"\"") <> "\""
      else
        value
      end
    end

    defp csv_escape(value), do: to_string(value)

    defp navigate_to_invites_tab(view, program) do
      view |> element("#view-roster-#{program.id}") |> render_click()
      view |> element("#roster-tab-invites") |> render_click()
    end

    test "successful import shows flash and refreshes invites", %{
      conn: conn,
      program: program
    } do
      csv_content = build_csv([%{first: "Emma", last: "Schmidt", email: "emma@test.com"}])

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      navigate_to_invites_tab(view, program)

      csv_file =
        file_input(view, "#csv-upload-form", :csv_file, [
          %{
            name: "import.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "import.csv")
      render_submit(view, "import_csv", %{})

      assert_flash(view, :info, "Imported 1 families.")
      assert has_element?(view, "#invites-table")
      refute has_element?(view, "#import-errors")
    end

    test "import with validation errors shows import-errors div", %{
      conn: conn,
      program: program
    } do
      csv_content = build_csv([%{email: ""}])

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      navigate_to_invites_tab(view, program)

      csv_file =
        file_input(view, "#csv-upload-form", :csv_file, [
          %{
            name: "bad.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "bad.csv")
      render_submit(view, "import_csv", %{})

      assert has_element?(view, "#import-errors")
      html = render(view)
      assert html =~ "Import failed"
    end

    test "import with parse errors shows import-errors div", %{
      conn: conn,
      program: program
    } do
      csv_content = "Wrong,Headers\nval1,val2\n"

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      navigate_to_invites_tab(view, program)

      csv_file =
        file_input(view, "#csv-upload-form", :csv_file, [
          %{
            name: "bad_headers.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "bad_headers.csv")
      render_submit(view, "import_csv", %{})

      assert has_element?(view, "#import-errors")
      html = render(view)
      assert html =~ "Import failed"
    end

    test "submitting without file shows no-file flash", %{
      conn: conn,
      program: program
    } do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")
      navigate_to_invites_tab(view, program)

      render_submit(view, "import_csv", %{})

      assert_flash(view, :error, "No file selected.")
    end
  end
end

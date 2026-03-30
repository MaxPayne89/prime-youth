defmodule KlassHeroWeb.Staff.StaffParticipationLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  describe "authentication and authorization" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      session_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: path}}} =
               live(conn, ~p"/staff/participation/#{session_id}")

      assert path =~ "/users/log-in"
    end

    test "redirects non-staff users to home", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      session_id = Ecto.UUID.generate()

      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/staff/participation/#{session_id}")
    end

    test "redirects to /staff/sessions when session belongs to unassigned program", %{conn: conn} do
      %{conn: conn, provider: provider} = register_and_log_in_staff(%{conn: conn})

      # Create a program with category "arts" — staff has tags: ["sports"]
      unassigned_program = insert(:program_schema, provider_id: provider.id, category: "arts")

      _listing =
        insert(:program_listing_schema,
          id: unassigned_program.id,
          provider_id: provider.id,
          category: "arts",
          title: "Art Workshop"
        )

      session =
        insert(:program_session_schema,
          program_id: unassigned_program.id,
          session_date: Date.utc_today(),
          status: :in_progress
        )

      assert {:error, {:live_redirect, %{to: "/staff/sessions"}}} =
               live(conn, ~p"/staff/participation/#{session.id}")
    end
  end

  describe "participation management" do
    setup :register_and_log_in_staff

    setup %{provider: provider} do
      program = insert(:program_schema, provider_id: provider.id, category: "sports")

      _listing =
        insert(:program_listing_schema,
          id: program.id,
          provider_id: provider.id,
          category: "sports",
          title: "Soccer Training"
        )

      session =
        insert(:program_session_schema,
          program_id: program.id,
          session_date: Date.utc_today(),
          status: :in_progress
        )

      parent = insert(:parent_profile_schema)

      {child, _parent} =
        insert_child_with_guardian(
          parent: parent,
          first_name: "Lina",
          last_name: "Schmidt"
        )

      record =
        insert(:participation_record_schema,
          session_id: session.id,
          child_id: child.id,
          parent_id: parent.id,
          status: :registered
        )

      %{session: session, parent: parent, child: child, record: record, program: program}
    end

    test "renders staff-participation element and child names in roster", %{
      conn: conn,
      session: session
    } do
      {:ok, view, _html} = live(conn, ~p"/staff/participation/#{session.id}")

      assert has_element?(view, "#staff-participation")
      assert has_element?(view, "div", "Lina")
      assert has_element?(view, "div", "Schmidt")
    end

    test "check_in succeeds and shows flash", %{
      conn: conn,
      session: session,
      record: record
    } do
      {:ok, view, _html} = live(conn, ~p"/staff/participation/#{session.id}")

      assert has_element?(view, "button[phx-click='check_in'][phx-value-id='#{record.id}']")

      view
      |> element("button[phx-click='check_in'][phx-value-id='#{record.id}']")
      |> render_click()

      assert_flash(view, :info, "Child checked in successfully")

      # After check-in, should now show the Check Out button
      assert has_element?(
               view,
               "button[phx-click='expand_checkout_form'][phx-value-id='#{record.id}']"
             )
    end

    test "expand checkout form, confirm checkout succeeds", %{
      conn: conn,
      session: session,
      record: record,
      user: user
    } do
      # Check in first
      {:ok, _} =
        KlassHero.Participation.record_check_in(%{
          record_id: record.id,
          checked_in_by: user.id
        })

      {:ok, view, _html} = live(conn, ~p"/staff/participation/#{session.id}")

      # Expand checkout form
      view
      |> element("button[phx-click='expand_checkout_form'][phx-value-id='#{record.id}']")
      |> render_click()

      assert has_element?(view, "#checkout-form-#{record.id}")

      # Submit checkout
      view
      |> form("#checkout-form-#{record.id}", %{checkout: %{notes: "Picked up by parent"}})
      |> render_submit()

      assert_flash(view, :info, "Child checked out successfully")
      refute has_element?(view, "#checkout-form-#{record.id}")
    end
  end
end

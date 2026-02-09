defmodule KlassHeroWeb.Provider.DashboardTeamTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.IdentityFixtures

  setup :register_and_log_in_provider

  describe "empty state" do
    test "shows empty state message when no staff members exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      assert has_element?(view, "#team-members-empty")
    end

    test "shows 'Add Team Member' button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      assert has_element?(view, "#add-member-btn")
    end
  end

  describe "member cards" do
    test "displays staff member card when members exist", %{conn: conn, provider: provider} do
      IdentityFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Alice",
        last_name: "Smith",
        role: "Head Coach"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      html = render(view)
      assert html =~ "Alice Smith"
      assert html =~ "Head Coach"
    end

    test "displays multiple staff member cards", %{conn: conn, provider: provider} do
      IdentityFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Alice",
        last_name: "Smith"
      )

      IdentityFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Bob",
        last_name: "Jones"
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      html = render(view)
      assert html =~ "Alice Smith"
      assert html =~ "Bob Jones"
    end

    test "shows tags as pills on member card", %{conn: conn, provider: provider} do
      IdentityFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Alice",
        last_name: "Smith",
        tags: ["sports", "arts"]
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      html = render(view)
      assert html =~ "sports"
      assert html =~ "arts"
    end

    test "shows qualifications on member card", %{conn: conn, provider: provider} do
      IdentityFixtures.staff_member_fixture(
        provider_id: provider.id,
        first_name: "Alice",
        last_name: "Smith",
        qualifications: ["First Aid", "UEFA B"]
      )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      html = render(view)
      assert html =~ "First Aid"
      assert html =~ "UEFA B"
    end
  end

  describe "add member flow" do
    test "clicking 'Add Team Member' opens the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      refute has_element?(view, "#staff-member-form")

      view |> element("#add-member-btn") |> render_click()

      assert has_element?(view, "#staff-member-form")
      assert has_element?(view, "#staff-form")
    end

    test "form submission creates a new staff member", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      view |> element("#add-member-btn") |> render_click()

      view
      |> form("#staff-form", %{
        "staff_member_schema" => %{
          "first_name" => "Charlie",
          "last_name" => "Brown",
          "role" => "Assistant Coach"
        }
      })
      |> render_submit()

      # Form should close after successful save
      refute has_element?(view, "#staff-member-form")

      # Flash should indicate success
      assert render(view) =~ "Team member added."
    end

    test "closing the form hides it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      view |> element("#add-member-btn") |> render_click()
      assert has_element?(view, "#staff-member-form")

      # Use the Cancel button text to disambiguate from the X close button
      view |> element("#staff-member-form button", "Cancel") |> render_click()
      refute has_element?(view, "#staff-member-form")
    end
  end

  describe "edit member flow" do
    test "clicking Edit opens pre-filled form", %{conn: conn, provider: provider} do
      staff =
        IdentityFixtures.staff_member_fixture(
          provider_id: provider.id,
          first_name: "Alice",
          last_name: "Smith",
          role: "Coach"
        )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      view
      |> element("button[phx-click=\"edit_member\"][phx-value-id=\"#{staff.id}\"]")
      |> render_click()

      assert has_element?(view, "#staff-member-form")
      html = render(view)
      assert html =~ "Edit Team Member"
    end

    test "saving edits updates the member", %{conn: conn, provider: provider} do
      staff =
        IdentityFixtures.staff_member_fixture(
          provider_id: provider.id,
          first_name: "Alice",
          last_name: "Smith",
          role: "Coach"
        )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      view
      |> element("button[phx-click=\"edit_member\"][phx-value-id=\"#{staff.id}\"]")
      |> render_click()

      view
      |> form("#staff-form", %{
        "staff_member_schema" => %{
          "role" => "Head Coach"
        }
      })
      |> render_submit()

      assert render(view) =~ "Team member updated."
    end
  end

  describe "delete member" do
    test "deleting a member shows success flash", %{conn: conn, provider: provider} do
      staff =
        IdentityFixtures.staff_member_fixture(
          provider_id: provider.id,
          first_name: "Alice",
          last_name: "Smith"
        )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      html = render(view)
      assert html =~ "Alice Smith"

      view
      |> element("button[phx-click=\"delete_member\"][phx-value-id=\"#{staff.id}\"]")
      |> render_click()

      assert render(view) =~ "Team member removed."
    end
  end

  describe "form validation" do
    test "validates on change and keeps form visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/team")

      view |> element("#add-member-btn") |> render_click()

      view
      |> form("#staff-form", %{
        "staff_member_schema" => %{
          "first_name" => "",
          "last_name" => ""
        }
      })
      |> render_change()

      # Form should still be visible after validation
      assert has_element?(view, "#staff-member-form")
    end
  end
end

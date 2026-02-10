defmodule KlassHeroWeb.Provider.DashboardProgramCreationTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.IdentityFixtures
  alias KlassHero.Repo

  setup :register_and_log_in_provider

  # Trigger: program creation requires a verified provider
  # Why: "New Program" button is disabled for unverified providers
  # Outcome: provider marked as verified so tests can interact with the button
  setup %{provider: provider} do
    provider
    |> Ecto.Changeset.change(%{
      verified: true,
      verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()

    :ok
  end

  describe "program creation form" do
    test "shows program form when add_program clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      refute has_element?(view, "#program-form")

      view |> element("#new-program-btn") |> render_click()

      assert has_element?(view, "#program-form")
    end

    test "validates program form on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        "program_schema" => %{"title" => ""}
      })
      |> render_change()

      assert has_element?(view, "#program-form")
    end

    test "creates program with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        "program_schema" => %{
          "title" => "Art Adventures",
          "description" => "Creative art program for kids",
          "category" => "arts",
          "price" => "50.00"
        }
      })
      |> render_submit()

      refute has_element?(view, "#program-form")
      assert render(view) =~ "Program created successfully."
    end

    test "creates program with instructor assigned", %{conn: conn, provider: provider} do
      staff =
        IdentityFixtures.staff_member_fixture(
          provider_id: provider.id,
          first_name: "Mike",
          last_name: "Johnson"
        )

      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        "program_schema" => %{
          "title" => "Soccer Camp",
          "description" => "Learn to play soccer",
          "category" => "sports",
          "price" => "75.00",
          "location" => "Sports Park",
          "instructor_id" => staff.id
        }
      })
      |> render_submit()

      refute has_element?(view, "#program-form")
      assert render(view) =~ "Program created successfully."
    end

    test "closes form on cancel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()
      assert has_element?(view, "#program-form")

      view |> element("button[phx-click=close_program_form]", "Cancel") |> render_click()
      refute has_element?(view, "#program-form")
    end
  end

  describe "program form validation errors" do
    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()

      view
      |> form("#program-form", %{
        "program_schema" => %{
          "title" => "",
          "description" => "",
          "category" => "",
          "price" => ""
        }
      })
      |> render_submit()

      assert has_element?(view, "#program-form")
      assert render(view) =~ "Please fix the errors below."
    end

    test "error flash is cleared on successful create", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/dashboard/programs")

      view |> element("#new-program-btn") |> render_click()

      # Submit invalid first
      view
      |> form("#program-form", %{
        "program_schema" => %{
          "title" => "",
          "description" => "",
          "category" => "",
          "price" => ""
        }
      })
      |> render_submit()

      assert render(view) =~ "Please fix the errors below."

      # Submit valid data
      view
      |> form("#program-form", %{
        "program_schema" => %{
          "title" => "Valid Program",
          "description" => "A valid description",
          "category" => "arts",
          "price" => "25.00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Program created successfully."
      refute html =~ "Please fix the errors below."
    end
  end
end

defmodule KlassHeroWeb.UserLive.RegistrationTierTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "tier selector" do
    test "shows tier selector when provider role is checked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      # Initially hidden
      refute has_element?(view, "#tier-selector")

      # Check provider checkbox
      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["provider"]
        }
      })
      |> render_change()

      assert has_element?(view, "#tier-selector")
      assert has_element?(view, "#tier-option-starter")
      assert has_element?(view, "#tier-option-professional")
      assert has_element?(view, "#tier-option-business_plus")
    end

    test "hides tier selector when provider role is unchecked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      # Check provider, then uncheck
      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["provider"]
        }
      })
      |> render_change()

      assert has_element?(view, "#tier-selector")

      view
      |> form("#registration_form", %{
        "user" => %{
          "name" => "Test",
          "email" => "test@example.com",
          "intended_roles" => ["parent"]
        }
      })
      |> render_change()

      refute has_element?(view, "#tier-selector")
    end
  end
end

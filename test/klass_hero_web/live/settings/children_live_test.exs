defmodule KlassHeroWeb.Settings.ChildrenLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.Family

  describe "page access" do
    setup :register_and_log_in_user

    test "authenticated user with parent profile can access /settings/children", %{
      conn: conn,
      user: user
    } do
      KlassHero.Factory.insert(:parent_schema, identity_id: user.id)
      {:ok, _view, html} = live(conn, ~p"/settings/children")

      assert html =~ "Children Profiles"
    end

    test "unauthenticated user is redirected", %{} do
      conn = build_conn()
      assert {:error, {:redirect, _}} = live(conn, ~p"/settings/children")
    end

    test "user without parent profile is redirected to settings", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/settings", flash: flash}}} =
               live(conn, ~p"/settings/children")

      assert flash["error"] =~ "parent profile"
    end
  end

  describe "empty state" do
    setup :register_and_log_in_user

    setup %{user: user} do
      parent = KlassHero.Factory.insert(:parent_schema, identity_id: user.id)
      %{parent: parent}
    end

    test "user with no children sees empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/children")

      assert has_element?(view, "[data-testid='no-children-state']")
    end
  end

  describe "list children" do
    setup :register_and_log_in_user_with_child

    test "user with children sees them listed", %{conn: conn, child: child} do
      {:ok, view, _html} = live(conn, ~p"/settings/children")

      refute has_element?(view, "[data-testid='no-children-state']")
      assert has_element?(view, "#children-list")
      assert render(view) =~ child.first_name
    end
  end

  describe "add child" do
    setup :register_and_log_in_user

    setup %{user: user} do
      parent = KlassHero.Factory.insert(:parent_schema, identity_id: user.id)
      %{parent: parent}
    end

    test "navigate to /settings/children/new shows modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/new")

      assert has_element?(view, "#child-form")
      assert has_element?(view, "#child-modal")
    end

    test "submitting valid form creates child", %{conn: conn, parent: parent} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/new")

      view
      |> form("#child-form",
        child: %{
          first_name: "Alice",
          last_name: "Wonder",
          date_of_birth: "2017-03-15"
        }
      )
      |> render_submit()

      # After successful creation, the view patches to index
      html = render(view)
      assert html =~ "Alice"

      # Verify child was created in the database
      children = Family.get_children(parent.id)
      assert length(children) == 1
      assert hd(children).first_name == "Alice"
      assert hd(children).last_name == "Wonder"
    end

    test "submitting empty form shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/new")

      # Use render_change to trigger validate first (which sets :action on changeset)
      view
      |> form("#child-form",
        child: %{
          first_name: "",
          last_name: "",
          date_of_birth: ""
        }
      )
      |> render_change()

      html =
        view
        |> form("#child-form",
          child: %{
            first_name: "",
            last_name: "",
            date_of_birth: ""
          }
        )
        |> render_submit()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "edit child" do
    setup :register_and_log_in_user_with_child

    test "navigating to edit shows form pre-filled", %{conn: conn, child: child} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/#{child.id}/edit")

      assert has_element?(view, "#child-form")
      assert has_element?(view, "#child-modal")
      html = render(view)
      assert html =~ child.first_name
    end

    test "updating child changes its data", %{conn: conn, child: child} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/#{child.id}/edit")

      view
      |> form("#child-form",
        child: %{
          first_name: "Updated",
          last_name: child.last_name,
          date_of_birth: to_string(child.date_of_birth)
        }
      )
      |> render_submit()

      # After update, view patches to index
      html = render(view)
      assert html =~ "Updated"

      {:ok, updated} = Family.get_child_by_id(child.id)
      assert updated.first_name == "Updated"
    end

    test "cannot edit child belonging to another parent", %{conn: conn} do
      other_parent = KlassHero.Factory.insert(:parent_schema)

      {other_child, _other_parent} =
        KlassHero.Factory.insert_child_with_guardian(parent: other_parent)

      # Should redirect back to index with error flash
      assert {:error, {:live_redirect, %{to: "/settings/children", flash: flash}}} =
               live(conn, ~p"/settings/children/#{other_child.id}/edit")

      assert flash["error"] =~ "permission"
    end
  end

  describe "delete child" do
    setup :register_and_log_in_user_with_child

    test "clicking delete removes child from list", %{conn: conn, child: child} do
      {:ok, view, _html} = live(conn, ~p"/settings/children")

      view
      |> element("button[phx-click='delete_child'][phx-value-id='#{child.id}']")
      |> render_click()

      refute render(view) =~ child.first_name
      assert {:error, :not_found} = Family.get_child_by_id(child.id)
    end

    test "cannot delete child belonging to another parent", %{conn: conn} do
      other_parent = KlassHero.Factory.insert(:parent_schema)

      {other_child, _other_parent} =
        KlassHero.Factory.insert_child_with_guardian(parent: other_parent)

      {:ok, view, _html} = live(conn, ~p"/settings/children")

      # Send delete event for another parent's child
      render_click(view, "delete_child", %{"id" => other_child.id})

      # Child should still exist
      assert {:ok, _} = Family.get_child_by_id(other_child.id)
    end
  end

  describe "consent toggle" do
    setup :register_and_log_in_user_with_child

    test "checking consent box on create grants consent", %{conn: conn, parent: parent} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/new")

      # Toggle consent checkbox
      render_click(view, "toggle_consent", %{"value" => "true"})

      view
      |> form("#child-form",
        child: %{
          first_name: "Consent",
          last_name: "Child",
          date_of_birth: "2018-01-01"
        }
      )
      |> render_submit()

      # After creation, view patches to index
      render(view)

      # Find the newly created child
      children = Family.get_children(parent.id)
      new_child = Enum.find(children, &(&1.first_name == "Consent"))
      assert new_child
      assert Family.child_has_active_consent?(new_child.id, "provider_data_sharing")
    end

    test "unchecking consent box on edit withdraws consent", %{
      conn: conn,
      child: child,
      parent: parent
    } do
      # Grant consent first
      Family.grant_consent(%{
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      })

      assert Family.child_has_active_consent?(child.id, "provider_data_sharing")

      {:ok, view, _html} = live(conn, ~p"/settings/children/#{child.id}/edit")

      # Uncheck consent (send without value to simulate unchecked)
      render_click(view, "toggle_consent", %{})

      view
      |> form("#child-form",
        child: %{
          first_name: child.first_name,
          last_name: child.last_name,
          date_of_birth: to_string(child.date_of_birth)
        }
      )
      |> render_submit()

      # After update, view patches to index
      render(view)

      refute Family.child_has_active_consent?(child.id, "provider_data_sharing")
    end
  end

  describe "validation" do
    setup :register_and_log_in_user

    setup %{user: user} do
      parent = KlassHero.Factory.insert(:parent_schema, identity_id: user.id)
      %{parent: parent}
    end

    test "live validation shows errors on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/children/new")

      html =
        view
        |> form("#child-form", child: %{first_name: "", last_name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "settings page integration" do
    setup :register_and_log_in_user

    test "settings page has link to children profiles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "/settings/children"
      assert html =~ "Children Profiles"
    end
  end
end

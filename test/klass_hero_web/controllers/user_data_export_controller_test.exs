defmodule KlassHeroWeb.UserDataExportControllerTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.AccountsFixtures
  import KlassHero.Factory

  setup %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /users/export-data" do
    test "downloads user data as JSON", %{conn: conn, user: user} do
      conn = get(conn, ~p"/users/export-data")

      assert response = json_response(conn, 200)
      assert response["user"]["email"] == user.email
      assert response["user"]["name"] == user.name
      assert response["user"]["id"] == user.id
      assert Map.has_key?(response, "exported_at")

      content_disposition = get_resp_header(conn, "content-disposition") |> List.first()
      assert content_disposition =~ "attachment"
      assert content_disposition =~ "klass_hero_data_export_"
      assert content_disposition =~ ".json"
    end

    test "does not include sensitive fields", %{conn: conn} do
      conn = get(conn, ~p"/users/export-data")

      response = json_response(conn, 200)
      refute Map.has_key?(response["user"], "hashed_password")
      refute Map.has_key?(response["user"], "password")
    end

    test "export includes children and consents", %{conn: conn, user: user} do
      parent = insert(:parent_profile_schema, identity_id: user.id)

      child =
        insert(:child_schema,
          parent_id: parent.id,
          first_name: "Emma",
          last_name: "Smith"
        )

      insert(:consent_schema,
        parent_id: parent.id,
        child_id: child.id,
        consent_type: "provider_data_sharing"
      )

      conn = get(conn, ~p"/users/export-data")

      response = json_response(conn, 200)
      assert [exported_child] = response["children"]
      assert exported_child["first_name"] == "Emma"
      assert exported_child["last_name"] == "Smith"
      assert [consent] = exported_child["consents"]
      assert consent["consent_type"] == "provider_data_sharing"
    end

    test "export without parent profile has no children key", %{conn: conn} do
      conn = get(conn, ~p"/users/export-data")

      response = json_response(conn, 200)
      refute Map.has_key?(response, "children")
    end

    test "requires authentication" do
      conn = build_conn()
      conn = get(conn, ~p"/users/export-data")

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end

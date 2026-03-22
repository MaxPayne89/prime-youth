defmodule KlassHeroWeb.UserLive.StaffInvitationTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.ProviderFixtures
  import Phoenix.LiveViewTest

  defp create_staff_with_invitation do
    provider = provider_profile_fixture()
    raw_bytes = :crypto.strong_rand_bytes(32)
    raw_token = Base.url_encode64(raw_bytes, padding: false)
    token_hash = :crypto.hash(:sha256, raw_bytes)

    staff =
      staff_member_fixture(%{
        provider_id: provider.id,
        first_name: "Jane",
        last_name: "Doe",
        email: "invited-#{System.unique_integer([:positive])}@example.com",
        invitation_status: :sent,
        invitation_token_hash: token_hash,
        invitation_sent_at: DateTime.utc_now()
      })

    {raw_token, staff, provider}
  end

  describe "valid invitation token" do
    test "renders registration form with pre-filled name and email", %{conn: conn} do
      {raw_token, staff, _provider} = create_staff_with_invitation()

      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      assert html =~ "Complete Your Registration"
      assert html =~ staff.email
      assert html =~ "Jane Doe"
    end

    test "email field is readonly", %{conn: conn} do
      {raw_token, _staff, _provider} = create_staff_with_invitation()

      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      assert html =~ "readonly"
    end

    test "renders password field", %{conn: conn} do
      {raw_token, _staff, _provider} = create_staff_with_invitation()

      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      assert html =~ ~s(type="password")
    end
  end

  describe "invalid invitation token" do
    test "shows invalid error for unknown token", %{conn: conn} do
      garbage_bytes = :crypto.strong_rand_bytes(32)
      bad_token = Base.url_encode64(garbage_bytes, padding: false)

      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/#{bad_token}")

      assert html =~ "Invalid Invitation"
    end

    test "shows invalid error for malformed token", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/not-valid-base64!!!")

      assert html =~ "Invalid Invitation"
    end
  end

  describe "expired invitation token" do
    test "shows expiry message for invitation older than 7 days", %{conn: conn} do
      provider = provider_profile_fixture()
      raw_bytes = :crypto.strong_rand_bytes(32)
      raw_token = Base.url_encode64(raw_bytes, padding: false)
      token_hash = :crypto.hash(:sha256, raw_bytes)

      eight_days_ago = DateTime.add(DateTime.utc_now(), -8, :day)

      _staff =
        staff_member_fixture(%{
          provider_id: provider.id,
          email: "expired-#{System.unique_integer([:positive])}@example.com",
          invitation_status: :sent,
          invitation_token_hash: token_hash,
          invitation_sent_at: eight_days_ago
        })

      {:ok, _lv, html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      assert html =~ "Invitation Expired"
    end
  end

  describe "successful registration" do
    test "creates user account and redirects to login with confirmation flash", %{conn: conn} do
      {raw_token, staff, _provider} = create_staff_with_invitation()

      {:ok, lv, _html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      {:ok, _lv, html} =
        lv
        |> form("#staff-registration-form",
          user: %{
            name: "Jane Doe",
            password: "verylongpassword123!"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "Account created"

      user = KlassHero.Repo.get_by!(KlassHero.Accounts.User, email: staff.email)
      assert user.intended_roles == [:staff_provider]
    end
  end

  describe "form validation errors" do
    test "shows error when password is too short", %{conn: conn} do
      {raw_token, _staff, _provider} = create_staff_with_invitation()

      {:ok, lv, _html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      result =
        lv
        |> form("#staff-registration-form",
          user: %{
            name: "Jane Doe",
            password: "short"
          }
        )
        |> render_submit()

      assert result =~ "at least 12 character"
    end

    test "shows error when name is missing", %{conn: conn} do
      {raw_token, _staff, _provider} = create_staff_with_invitation()

      {:ok, lv, _html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      result =
        lv
        |> form("#staff-registration-form",
          user: %{
            name: "",
            password: "verylongpassword123!"
          }
        )
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end

    test "validate event updates form without submitting", %{conn: conn} do
      {raw_token, _staff, _provider} = create_staff_with_invitation()

      {:ok, lv, _html} = live(conn, ~p"/users/staff-invitation/#{raw_token}")

      result =
        lv
        |> form("#staff-registration-form",
          user: %{
            name: "J",
            password: ""
          }
        )
        |> render_change()

      assert result =~ "staff-registration-form"
    end
  end
end

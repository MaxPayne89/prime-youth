defmodule KlassHeroWeb.Admin.EmailsLiveTest do
  use KlassHeroWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KlassHero.MessagingFixtures

  setup :register_and_log_in_admin

  describe "Index" do
    test "lists inbound emails", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture(%{subject: "Hello Admin"})
      {:ok, view, _html} = live(conn, ~p"/admin/emails")
      assert has_element?(view, "#emails-table")
      assert render(view) =~ "Hello Admin"
      assert render(view) =~ email.from_address
    end

    test "filters by status", %{conn: conn} do
      MessagingFixtures.inbound_email_fixture(%{status: "unread", subject: "Unread One"})
      MessagingFixtures.inbound_email_fixture(%{status: "read", subject: "Read One"})

      {:ok, view, _html} = live(conn, ~p"/admin/emails")
      assert render(view) =~ "Unread One"
      assert render(view) =~ "Read One"

      view |> element("#filter-unread") |> render_click()
      assert render(view) =~ "Unread One"
      refute render(view) =~ "Read One"
    end

    test "shows empty state when no emails", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/emails")
      assert has_element?(view, "#emails-empty")
    end
  end

  describe "Show" do
    test "displays email detail with sanitized HTML", %{conn: conn} do
      email =
        MessagingFixtures.inbound_email_fixture(%{
          subject: "Important Message",
          body_html: "<p>Hello <strong>world</strong></p><script>evil()</script>"
        })

      {:ok, view, html} = live(conn, ~p"/admin/emails/#{email.id}")
      assert html =~ "Important Message"
      assert html =~ "<strong>world</strong>"
      refute html =~ "<script>"
    end

    test "shows reply form", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/emails/#{email.id}")
      assert has_element?(view, "#reply-form")
    end

    test "navigates back to index", %{conn: conn} do
      email = MessagingFixtures.inbound_email_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/emails/#{email.id}")
      assert has_element?(view, "#back-to-emails")
    end

    test "redirects on invalid id", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/emails"}}} =
               live(conn, ~p"/admin/emails/not-a-uuid")
    end
  end
end

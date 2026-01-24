defmodule KlassHeroWeb.Provider.MessagesLive.IndexTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository

  describe "authentication and authorization" do
    test "requires authentication", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/provider/messages")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/users/log-in"
    end

    test "requires provider role", %{conn: conn} do
      # Register as regular user, not provider
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert {:error, redirect} = live(conn, ~p"/provider/messages")
      assert {:redirect, %{to: path}} = redirect
      assert path == "/"
    end
  end

  describe "empty state" do
    setup :register_and_log_in_provider

    test "renders empty state when no conversations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/messages")

      assert has_element?(view, "h3", "No conversations yet")
    end
  end

  describe "conversation list" do
    setup :register_and_log_in_provider

    test "renders conversation list", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, _msg} =
        MessageRepository.create(%{
          conversation_id: conversation.id,
          sender_id: user.id,
          content: "Hello there!"
        })

      {:ok, view, _html} = live(conn, ~p"/provider/messages")

      assert has_element?(view, "#conversations")
      refute has_element?(view, "h3", "No conversations yet")
    end

    test "clicking conversation navigates to provider show page", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages")

      html = render(view)
      assert html =~ "/provider/messages/#{conversation.id}"
    end
  end

  describe "page title" do
    setup :register_and_log_in_provider

    test "sets page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/provider/messages")

      assert has_element?(view, "h1", "Messages")
    end
  end
end

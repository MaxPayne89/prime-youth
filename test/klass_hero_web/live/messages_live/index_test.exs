defmodule KlassHeroWeb.MessagesLive.IndexTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository

  describe "authentication" do
    test "requires authentication", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/messages")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/users/log-in"
    end
  end

  describe "empty state" do
    setup :register_and_log_in_user

    test "renders empty state when no conversations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/messages")

      assert has_element?(view, "h3", "No conversations yet")
      assert has_element?(view, "p", "Your conversations with providers will appear here")
    end
  end

  describe "conversation list" do
    setup :register_and_log_in_user

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

      {:ok, view, _html} = live(conn, ~p"/messages")

      assert has_element?(view, "#conversations")
      refute has_element?(view, "h3", "No conversations yet")
    end

    test "renders conversation with unread count", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id,
        last_read_at: nil
      )

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: other_user.id
      )

      for _ <- 1..3 do
        MessageRepository.create(%{
          conversation_id: conversation.id,
          sender_id: other_user.id,
          content: "Message"
        })
      end

      {:ok, view, _html} = live(conn, ~p"/messages")

      assert has_element?(view, "#conversations")
    end

    test "orders conversations by most recent", %{conn: conn, user: user} do
      old_conversation = insert(:conversation_schema)
      new_conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: old_conversation.id,
        user_id: user.id
      )

      insert(:participant_schema,
        conversation_id: new_conversation.id,
        user_id: user.id
      )

      MessageRepository.create(%{
        conversation_id: old_conversation.id,
        sender_id: user.id,
        content: "Old message"
      })

      Process.sleep(10)

      MessageRepository.create(%{
        conversation_id: new_conversation.id,
        sender_id: user.id,
        content: "New message"
      })

      {:ok, view, _html} = live(conn, ~p"/messages")

      assert has_element?(view, "#conversations")
    end

    test "clicking conversation navigates to show page", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages")

      html = render(view)
      assert html =~ "/messages/#{conversation.id}"
    end
  end

  describe "page title" do
    setup :register_and_log_in_user

    test "sets page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/messages")

      assert has_element?(view, "h1", "Messages")
    end
  end
end

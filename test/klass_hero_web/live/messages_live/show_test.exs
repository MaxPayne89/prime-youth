defmodule KlassHeroWeb.MessagesLive.ShowTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository

  describe "authentication" do
    test "requires authentication", %{conn: conn} do
      conversation = insert(:conversation_schema)

      assert {:error, redirect} = live(conn, ~p"/messages/#{conversation.id}")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/users/log-in"
    end
  end

  describe "access control" do
    setup :register_and_log_in_user

    test "redirects when conversation not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/messages", flash: flash}}} =
               live(conn, ~p"/messages/#{Ecto.UUID.generate()}")

      assert flash["error"] == "Conversation not found"
    end

    test "redirects when not participant", %{conn: conn} do
      conversation = insert(:conversation_schema)

      assert {:error, {:live_redirect, %{to: "/messages", flash: flash}}} =
               live(conn, ~p"/messages/#{conversation.id}")

      assert flash["error"] == "You don't have access to this conversation"
    end
  end

  describe "conversation view" do
    setup :register_and_log_in_user

    test "renders conversation with messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, _msg} =
        MessageRepository.create(%{
          conversation_id: conversation.id,
          sender_id: user.id,
          content: "Hello world!"
        })

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      assert has_element?(view, "#messages")
      assert has_element?(view, "#message-form")
    end

    test "renders empty state when no messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      assert has_element?(view, "h3", "No messages yet")
    end

    test "renders back navigation link", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      html = render(view)
      assert html =~ "/messages"
    end
  end

  describe "sending messages" do
    setup :register_and_log_in_user

    test "send_message event sends message", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      view
      |> form("#message-form", %{"content" => "Hello from test!"})
      |> render_submit()

      {:ok, messages, _} =
        MessageRepository.list_for_conversation(conversation.id, limit: 10)

      assert length(messages) == 1
      assert hd(messages).content == "Hello from test!"
    end

    test "ignores empty messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      view
      |> form("#message-form", %{"content" => "   "})
      |> render_submit()

      {:ok, messages, _} =
        MessageRepository.list_for_conversation(conversation.id, limit: 10)

      assert messages == []
    end

    test "clears input after sending", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      view
      |> form("#message-form", %{"content" => "Hello!"})
      |> render_submit()

      html = render(view)
      refute html =~ "Hello!"
    end
  end

  describe "broadcast conversations" do
    setup :register_and_log_in_user

    test "shows broadcast badge for program broadcast", %{conn: conn, user: user} do
      conversation = insert(:broadcast_conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      assert has_element?(view, "span", "Broadcast")
    end
  end

  describe "page title" do
    setup :register_and_log_in_user

    test "sets page title to Conversation for direct messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Conversation")
    end

    test "sets page title to subject for broadcast with subject", %{conn: conn, user: user} do
      conversation = insert(:broadcast_conversation_schema, subject: "Important Update")

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Important Update")
    end
  end
end

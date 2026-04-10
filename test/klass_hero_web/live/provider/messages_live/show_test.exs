defmodule KlassHeroWeb.Provider.MessagesLive.ShowTest do
  use KlassHeroWeb.ConnCase, async: true

  import KlassHero.Factory
  import Phoenix.LiveViewTest

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.MessageRepository

  describe "authentication and authorization" do
    test "requires authentication", %{conn: conn} do
      conversation = insert(:conversation_schema)

      assert {:error, redirect} = live(conn, ~p"/provider/messages/#{conversation.id}")
      assert {:redirect, %{to: path}} = redirect
      assert path =~ "/users/log-in"
    end

    test "requires provider role", %{conn: conn} do
      conversation = insert(:conversation_schema)
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      assert {:error, redirect} = live(conn, ~p"/provider/messages/#{conversation.id}")
      assert {:redirect, %{to: path}} = redirect
      assert path == "/"
    end
  end

  describe "access control" do
    setup :register_and_log_in_provider

    test "redirects when conversation not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/provider/messages", flash: flash}}} =
               live(conn, ~p"/provider/messages/#{Ecto.UUID.generate()}")

      assert flash["error"] == "Conversation not found"
    end

    test "redirects when not participant", %{conn: conn} do
      conversation = insert(:conversation_schema)

      assert {:error, {:live_redirect, %{to: "/provider/messages", flash: flash}}} =
               live(conn, ~p"/provider/messages/#{conversation.id}")

      assert flash["error"] == "You don't have access to this conversation"
    end
  end

  describe "conversation view" do
    setup :register_and_log_in_provider

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

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "#messages")
      assert has_element?(view, "#message-form")
    end

    test "renders empty state when no messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "h3", "No messages yet")
    end

    test "renders back navigation to provider messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      html = render(view)
      assert html =~ "/provider/messages"
    end
  end

  describe "sending messages" do
    setup :register_and_log_in_provider

    test "send_message event sends message", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      view
      |> form("#message-form", %{"content" => "Hello from provider!"})
      |> render_submit()

      {:ok, messages, _} =
        MessageRepository.list_for_conversation(conversation.id, limit: 10)

      assert length(messages) == 1
      assert hd(messages).content == "Hello from provider!"
    end

    test "ignores empty messages", %{conn: conn, user: user} do
      conversation = insert(:conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

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

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      view
      |> form("#message-form", %{"content" => "Hello from provider!"})
      |> render_submit()

      assert_push_event(view, "clear_message_input", %{})

      html = render(view)
      refute html =~ "Hello from provider!"
    end
  end

  describe "direct conversation title" do
    setup :register_and_log_in_provider

    test "shows parent name and enrolled child first name in header", %{
      conn: conn,
      user: provider_user,
      provider: provider
    } do
      parent_user =
        AccountsFixtures.user_fixture(%{
          name: "Sarah Johnson",
          intended_roles: [:parent]
        })

      parent = insert(:parent_profile_schema, identity_id: parent_user.id)
      {child, _} = insert_child_with_guardian(first_name: "Emma", last_name: "Smith", parent: parent)
      program = insert(:program_schema)

      insert(:enrollment_schema,
        program_id: program.id,
        child_id: child.id,
        parent_id: parent.id,
        status: "pending"
      )

      conversation =
        insert(:conversation_schema,
          provider_id: provider.id,
          program_id: program.id,
          type: "direct"
        )

      insert(:participant_schema, conversation_id: conversation.id, user_id: provider_user.id)
      insert(:participant_schema, conversation_id: conversation.id, user_id: parent_user.id)

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Sarah Johnson")
      assert has_element?(view, "h1", "Emma")
    end

    test "shows only parent name when no enrolled children", %{
      conn: conn,
      user: provider_user,
      provider: provider
    } do
      parent_user =
        AccountsFixtures.user_fixture(%{
          name: "Sarah Johnson",
          intended_roles: [:parent]
        })

      program = insert(:program_schema)

      conversation =
        insert(:conversation_schema,
          provider_id: provider.id,
          program_id: program.id,
          type: "direct"
        )

      insert(:participant_schema, conversation_id: conversation.id, user_id: provider_user.id)
      insert(:participant_schema, conversation_id: conversation.id, user_id: parent_user.id)

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Sarah Johnson")
      refute render(view) =~ "  for  "
    end

    test "shows parent name when conversation has no program_id", %{
      conn: conn,
      user: provider_user,
      provider: provider
    } do
      parent_user =
        AccountsFixtures.user_fixture(%{
          name: "Sarah Johnson",
          intended_roles: [:parent]
        })

      conversation =
        insert(:conversation_schema,
          provider_id: provider.id,
          program_id: nil,
          type: "direct"
        )

      insert(:participant_schema, conversation_id: conversation.id, user_id: provider_user.id)
      insert(:participant_schema, conversation_id: conversation.id, user_id: parent_user.id)

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Sarah Johnson")
    end

    test "falls back to 'Conversation' when there is no other participant", %{
      conn: conn,
      user: provider_user,
      provider: provider
    } do
      conversation =
        insert(:conversation_schema,
          provider_id: provider.id,
          type: "direct"
        )

      # Only the provider is a participant — no parent to resolve
      insert(:participant_schema, conversation_id: conversation.id, user_id: provider_user.id)

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "h1", "Conversation")
    end
  end

  describe "broadcast conversations" do
    setup :register_and_log_in_provider

    test "shows broadcast badge for program broadcast", %{conn: conn, user: user} do
      conversation = insert(:broadcast_conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "span", "Broadcast")
    end

    test "shows message form (not reply bar) for provider on broadcast", %{conn: conn, user: user} do
      conversation = insert(:broadcast_conversation_schema)

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      {:ok, view, _html} = live(conn, ~p"/provider/messages/#{conversation.id}")

      assert has_element?(view, "#message-form")
      refute has_element?(view, "#broadcast-reply-bar")
    end
  end
end

defmodule KlassHeroWeb.MessagingLiveHelper do
  @moduledoc """
  Shared helper module for messaging LiveViews.

  Provides common functionality for both parent and provider
  conversation views, reducing code duplication while maintaining
  the flexibility needed for different navigation paths.
  """

  use Gettext, backend: KlassHeroWeb.Gettext

  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView,
    only: [connected?: 1, put_flash: 3, push_navigate: 2, stream: 3, stream: 4, stream_insert: 4]

  alias KlassHero.Messaging
  alias KlassHero.Messaging.Domain.Models.Message
  alias KlassHero.Messaging.Repositories
  alias KlassHero.Shared.Domain.Events.DomainEvent

  require Logger

  @doc """
  Mounts a conversation show view with all necessary assigns.

  ## Options
  - `:back_path` - The path to navigate back to (required)

  ## Returns
  - `{:ok, socket}` on success
  - `{:ok, socket}` with flash and redirect on error
  """
  def mount_conversation_show(socket, conversation_id, opts) do
    back_path = Keyword.fetch!(opts, :back_path)
    user_id = socket.assigns.current_scope.user.id
    mark_as_read? = connected?(socket)

    case Messaging.get_conversation(conversation_id, user_id, mark_as_read: mark_as_read?) do
      {:ok,
       %{
         conversation: conversation,
         messages: messages,
         has_more: has_more,
         sender_names: sender_names
       }} ->
        if connected?(socket), do: subscribe_to_conversation(conversation_id)

        reversed_messages = Enum.reverse(messages)

        socket =
          socket
          |> assign(:page_title, get_conversation_title(conversation))
          |> assign(:conversation, conversation)
          |> assign(:has_more, has_more)
          |> assign(:messages_empty?, Enum.empty?(messages))
          |> assign(:sender_names, sender_names)
          |> assign(:form, Phoenix.Component.to_form(%{"content" => ""}))
          |> assign(:back_path, back_path)
          |> stream(:messages, reversed_messages)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Conversation not found"))
         |> push_navigate(to: back_path)}

      {:error, :not_participant} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You don't have access to this conversation"))
         |> push_navigate(to: back_path)}
    end
  end

  @doc """
  Handles the send_message event.

  Returns `{:noreply, socket}` with updated form or error flash.
  """
  def handle_send_message(%{"content" => content}, socket) do
    content = String.trim(content)

    if content == "" do
      {:noreply, socket}
    else
      conversation_id = socket.assigns.conversation.id
      sender_id = socket.assigns.current_scope.user.id

      case Messaging.send_message(conversation_id, sender_id, content) do
        {:ok, _message} ->
          {:noreply, assign(socket, :form, Phoenix.Component.to_form(%{"content" => ""}))}

        {:error, reason} ->
          Logger.error("Failed to send message", reason: reason)
          {:noreply, put_flash(socket, :error, gettext("Failed to send message"))}
      end
    end
  end

  @doc """
  Handles incoming message_sent domain events.

  Adds the new message to the stream and updates sender names if needed.
  """
  def handle_message_sent_event(%DomainEvent{payload: payload} = _event, socket) do
    if payload.conversation_id == socket.assigns.conversation.id do
      user_id = socket.assigns.current_scope.user.id
      Messaging.mark_as_read(payload.conversation_id, user_id)

      sender_names = socket.assigns.sender_names
      sender_name = Map.get(sender_names, payload.sender_id)

      socket =
        if sender_name do
          socket
        else
          update_sender_names_for_new_message(socket, payload.sender_id)
        end

      message = build_message_from_event(payload)

      socket =
        socket
        |> assign(:messages_empty?, false)
        |> stream_insert(:messages, message, at: -1)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @doc """
  Mounts a conversation index view with all necessary assigns.

  ## Options
  - `:navigate_base` - Base path for conversation links (required)
  """
  def mount_conversation_index(socket, opts) do
    navigate_base = Keyword.fetch!(opts, :navigate_base)
    user_id = socket.assigns.current_scope.user.id

    if connected?(socket), do: subscribe_to_user_updates(user_id)

    {:ok, conversations, _has_more} = Messaging.list_conversations(user_id)

    socket =
      socket
      |> assign(:page_title, gettext("Messages"))
      |> assign(:navigate_base, navigate_base)
      |> assign(:conversations_empty?, Enum.empty?(conversations))
      |> Phoenix.LiveView.stream_configure(:conversations,
        dom_id: &"conversations-#{&1.conversation.id}"
      )
      |> stream(:conversations, conversations)

    {:ok, socket}
  end

  @doc """
  Refreshes the conversation list after updates.
  """
  def refresh_conversations(socket) do
    user_id = socket.assigns.current_scope.user.id
    {:ok, conversations, _has_more} = Messaging.list_conversations(user_id)

    socket =
      socket
      |> assign(:conversations_empty?, Enum.empty?(conversations))
      |> stream(:conversations, conversations, reset: true)

    {:noreply, socket}
  end

  @doc """
  Returns the title for a conversation.
  """
  def get_conversation_title(%{type: :program_broadcast, subject: subject})
      when not is_nil(subject) do
    subject
  end

  def get_conversation_title(%{type: :program_broadcast}) do
    gettext("Program Broadcast")
  end

  def get_conversation_title(_conversation) do
    gettext("Conversation")
  end

  @doc """
  Checks if a message was sent by the given user.
  """
  def own_message?(message, user_id) do
    message.sender_id == user_id
  end

  @doc """
  Gets the sender name from the sender_names map.
  """
  def get_sender_name(sender_names, sender_id) do
    Map.get(sender_names, sender_id, "Unknown")
  end

  defp build_message_from_event(payload) do
    %Message{
      id: payload.message_id,
      conversation_id: payload.conversation_id,
      sender_id: payload.sender_id,
      content: payload.content,
      message_type: payload.message_type,
      inserted_at: payload.sent_at
    }
  end

  defp update_sender_names_for_new_message(socket, sender_id) do
    user_resolver = Repositories.users()

    case user_resolver.get_display_name(sender_id) do
      {:ok, name} ->
        sender_names = Map.put(socket.assigns.sender_names, sender_id, name)
        assign(socket, :sender_names, sender_names)

      {:error, :not_found} ->
        socket
    end
  end

  defp subscribe_to_conversation(conversation_id) do
    topic = Messaging.conversation_topic(conversation_id)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
  end

  defp subscribe_to_user_updates(user_id) do
    topic = Messaging.user_messages_topic(user_id)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
  end
end

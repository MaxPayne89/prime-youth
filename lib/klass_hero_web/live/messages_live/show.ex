defmodule KlassHeroWeb.MessagesLive.Show do
  @moduledoc """
  LiveView for displaying a conversation with messages.

  Features:
  - Displays messages in chronological order
  - Real-time message updates via PubSub
  - Message input and sending
  - Auto-mark as read on view
  - Stream-based collection for memory efficiency
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Messaging
  alias KlassHero.Messaging.EventPublisher

  require Logger

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
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
          |> assign(:form, to_form(%{"content" => ""}))
          |> stream(:messages, reversed_messages)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Conversation not found"))
         |> push_navigate(to: ~p"/messages")}

      {:error, :not_participant} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("You don't have access to this conversation"))
         |> push_navigate(to: ~p"/messages")}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    content = String.trim(content)

    if content == "" do
      {:noreply, socket}
    else
      conversation_id = socket.assigns.conversation.id
      sender_id = socket.assigns.current_scope.user.id

      case Messaging.send_message(conversation_id, sender_id, content) do
        {:ok, _message} ->
          {:noreply, assign(socket, :form, to_form(%{"content" => ""}))}

        {:error, reason} ->
          Logger.error("Failed to send message", reason: reason)
          {:noreply, put_flash(socket, :error, gettext("Failed to send message"))}
      end
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.conversation_id == socket.assigns.conversation.id do
      user_id = socket.assigns.current_scope.user.id
      Messaging.mark_as_read(message.conversation_id, user_id)

      sender_names = socket.assigns.sender_names
      sender_name = Map.get(sender_names, message.sender_id)

      socket =
        if sender_name do
          socket
        else
          update_sender_names_for_new_message(socket, message.sender_id)
        end

      socket =
        socket
        |> assign(:messages_empty?, false)
        |> stream_insert(:messages, message, at: -1)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:messages_read, %{user_id: user_id, read_at: _read_at}}, socket) do
    Logger.debug("Messages read by user", user_id: user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_sender_names_for_new_message(socket, sender_id) do
    user_resolver = Application.get_env(:klass_hero, :messaging)[:for_resolving_users]

    case user_resolver.get_display_name(sender_id) do
      {:ok, name} ->
        sender_names = Map.put(socket.assigns.sender_names, sender_id, name)
        assign(socket, :sender_names, sender_names)

      {:error, :not_found} ->
        socket
    end
  end

  defp subscribe_to_conversation(conversation_id) do
    topic = EventPublisher.conversation_topic(conversation_id)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
  end

  defp get_conversation_title(%{type: :program_broadcast, subject: subject})
       when not is_nil(subject) do
    subject
  end

  defp get_conversation_title(%{type: :program_broadcast}) do
    gettext("Program Broadcast")
  end

  defp get_conversation_title(_conversation) do
    gettext("Conversation")
  end

  defp is_own_message?(message, user_id) do
    message.sender_id == user_id
  end

  defp get_sender_name(sender_names, sender_id) do
    Map.get(sender_names, sender_id, "Unknown")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-gray-50">
      <div class="max-w-2xl mx-auto w-full flex flex-col h-full bg-white shadow-sm">
        <!-- Header -->
        <header class="sticky top-0 z-10 bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-3">
          <.link navigate={~p"/messages"} class="text-gray-500 hover:text-gray-700">
            <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 19l-7-7 7-7"
              />
            </svg>
          </.link>
          <div class="flex-1">
            <h1 class="text-lg font-semibold text-gray-900 truncate">{@page_title}</h1>
            <.broadcast_badge :if={@conversation.type == :program_broadcast} />
          </div>
        </header>
        
    <!-- Messages -->
        <div
          id="messages-container"
          class="flex-1 overflow-y-auto p-4 space-y-3"
          phx-hook="ScrollToBottom"
        >
          <div id="messages" phx-update="stream" class="space-y-3">
            <.message_bubble
              :for={{dom_id, message} <- @streams.messages}
              id={dom_id}
              message={message}
              is_own={is_own_message?(message, @current_scope.user.id)}
              sender_name={get_sender_name(@sender_names, message.sender_id)}
            />
          </div>
          <.messages_empty_state :if={@messages_empty?} />
        </div>
        
    <!-- Message Input -->
        <.message_input form={@form} />
      </div>
    </div>
    """
  end
end

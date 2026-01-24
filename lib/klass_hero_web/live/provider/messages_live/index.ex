defmodule KlassHeroWeb.Provider.MessagesLive.Index do
  @moduledoc """
  LiveView for displaying the provider's conversation list.

  Similar to the parent version but includes provider-specific features
  like broadcast conversations.
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Messaging
  alias KlassHero.Messaging.EventPublisher
  alias KlassHero.Shared.Domain.Events.DomainEvent

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id

    if connected?(socket), do: subscribe_to_updates(user_id)

    {:ok, conversations, _has_more} = Messaging.list_conversations(user_id)

    socket =
      socket
      |> assign(:page_title, gettext("Messages"))
      |> assign(:conversations_empty?, Enum.empty?(conversations))
      |> stream_configure(:conversations, dom_id: &"conversations-#{&1.conversation.id}")
      |> stream(:conversations, conversations)

    {:ok, socket}
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :message_sent}}, socket) do
    refresh_conversations(socket)
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :conversation_created}}, socket) do
    refresh_conversations(socket)
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp refresh_conversations(socket) do
    user_id = socket.assigns.current_scope.user.id
    {:ok, conversations, _has_more} = Messaging.list_conversations(user_id)

    socket =
      socket
      |> assign(:conversations_empty?, Enum.empty?(conversations))
      |> stream(:conversations, conversations, reset: true)

    {:noreply, socket}
  end

  defp subscribe_to_updates(user_id) do
    topic = EventPublisher.user_messages_topic(user_id)
    Phoenix.PubSub.subscribe(KlassHero.PubSub, topic)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-2xl mx-auto bg-white min-h-screen shadow-sm">
        <!-- Header -->
        <header class="sticky top-0 z-10 bg-white border-b border-gray-200 px-4 py-3">
          <h1 class="text-xl font-semibold text-gray-900">{gettext("Messages")}</h1>
        </header>
        
    <!-- Conversation List -->
        <div id="conversations" phx-update="stream" class="divide-y divide-gray-100">
          <.conversation_card
            :for={{dom_id, conv_data} <- @streams.conversations}
            id={dom_id}
            conversation={conv_data.conversation}
            unread_count={conv_data.unread_count}
            latest_message={conv_data.latest_message}
            other_participant_name={conv_data.other_participant_name}
            navigate={~p"/provider/messages/#{conv_data.conversation.id}"}
          />
          <div :if={@conversations_empty?} id="conversations-empty-state" class="p-4">
            <.conversations_empty_state />
          </div>
        </div>
      </div>
    </div>
    """
  end
end

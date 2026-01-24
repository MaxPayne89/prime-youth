defmodule KlassHeroWeb.MessagesLive.Index do
  @moduledoc """
  LiveView for displaying the user's conversation list (parent view).

  Features:
  - Lists all conversations with unread counts
  - Real-time updates via PubSub
  - Stream-based collection for memory efficiency
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHeroWeb.MessagingLiveHelper
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    MessagingLiveHelper.mount_conversation_index(socket, navigate_base: "/messages")
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :message_sent}}, socket) do
    MessagingLiveHelper.refresh_conversations(socket)
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :conversation_created}}, socket) do
    MessagingLiveHelper.refresh_conversations(socket)
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <!-- Gradient Header -->
      <header class={[Theme.gradient(:primary), "px-6 py-4"]}>
        <div class="max-w-2xl mx-auto flex items-center gap-3">
          <.icon name="hero-chat-bubble-left-right" class="w-7 h-7 text-white" />
          <h1 class={[Theme.typography(:section_title), "text-white"]}>
            {gettext("Messages")}
          </h1>
        </div>
      </header>
      
    <!-- Content -->
      <div class="max-w-2xl mx-auto -mt-2">
        <div class={[Theme.bg(:surface), Theme.rounded(:xl), "shadow-sm overflow-hidden"]}>
          <!-- Conversation List -->
          <div id="conversations" phx-update="stream" class={["divide-y", Theme.border_color(:light)]}>
            <.conversation_card
              :for={{dom_id, conv_data} <- @streams.conversations}
              id={dom_id}
              conversation={conv_data.conversation}
              unread_count={conv_data.unread_count}
              latest_message={conv_data.latest_message}
              other_participant_name={conv_data.other_participant_name}
              navigate={@navigate_base <> "/" <> conv_data.conversation.id}
            />
            <div :if={@conversations_empty?} id="conversations-empty-state" class="p-4">
              <.conversations_empty_state />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

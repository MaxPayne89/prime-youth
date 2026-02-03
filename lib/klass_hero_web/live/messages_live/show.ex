defmodule KlassHeroWeb.MessagesLive.Show do
  @moduledoc """
  LiveView for displaying a conversation with messages (parent view).

  Features:
  - Displays messages in chronological order
  - Real-time message updates via PubSub
  - Message input and sending
  - Auto-mark as read on view
  - Stream-based collection for memory efficiency
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHeroWeb.MessagingLiveHelper
  alias KlassHeroWeb.Theme

  require Logger

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
    MessagingLiveHelper.mount_conversation_show(socket, conversation_id, back_path: ~p"/messages")
  end

  @impl true
  def handle_event("send_message", params, socket) do
    MessagingLiveHelper.handle_send_message(params, socket)
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :message_sent} = event}, socket) do
    MessagingLiveHelper.handle_message_sent_event(event, socket)
  end

  @impl true
  def handle_info({:domain_event, %DomainEvent{event_type: :messages_read} = event}, socket) do
    Logger.debug("Messages read by user", user_id: event.payload.user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["flex flex-col h-screen", Theme.bg(:muted)]}>
      <div class="max-w-2xl mx-auto w-full flex flex-col h-full">
        <!-- Gradient Header -->
        <header class={[Theme.gradient(:primary), "px-4 py-3 flex items-center gap-3"]}>
          <.link navigate={@back_path} class="text-white/80 hover:text-white">
            <.icon name="hero-arrow-left" class="w-6 h-6" />
          </.link>
          <div class={[
            "w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold",
            avatar_color(@page_title)
          ]}>
            {String.first(@page_title) |> String.upcase()}
          </div>
          <div class="flex-1">
            <h1 class="text-lg font-semibold text-white truncate">{@page_title}</h1>
            <.broadcast_badge :if={@conversation.type == :program_broadcast} class="text-white/80" />
          </div>
        </header>
        
    <!-- Messages Container -->
        <div class={[Theme.bg(:surface), "flex-1 flex flex-col shadow-sm overflow-hidden"]}>
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
                is_own={MessagingLiveHelper.own_message?(message, @current_scope.user.id)}
                sender_name={MessagingLiveHelper.get_sender_name(@sender_names, message.sender_id)}
              />
            </div>
            <.messages_empty_state :if={@messages_empty?} />
          </div>
          
    <!-- Message Input -->
          <.message_input form={@form} />
        </div>
      </div>
    </div>
    """
  end

  defp avatar_color(name) do
    colors = [
      "bg-prime-cyan-500",
      "bg-prime-magenta-500",
      "bg-prime-yellow-500",
      "bg-emerald-500",
      "bg-blue-500",
      "bg-purple-500",
      "bg-rose-500"
    ]

    index = :erlang.phash2(name, length(colors))
    Enum.at(colors, index)
  end
end

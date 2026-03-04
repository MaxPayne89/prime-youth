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
  use KlassHeroWeb.MessagingLiveHelper, :show

  import KlassHeroWeb.MessagingComponents

  alias KlassHeroWeb.Theme

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
    MessagingLiveHelper.mount_conversation_show(socket, conversation_id, back_path: ~p"/messages")
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
end

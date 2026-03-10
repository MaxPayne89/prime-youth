defmodule KlassHeroWeb.Provider.MessagesLive.Show do
  @moduledoc """
  LiveView for displaying a conversation with messages (provider view).

  Similar to the parent version but with provider-specific navigation.
  """

  use KlassHeroWeb, :live_view
  use KlassHeroWeb.MessagingLiveHelper, :show

  import KlassHeroWeb.MessagingComponents

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
    MessagingLiveHelper.mount_conversation_show(socket, conversation_id,
      back_path: ~p"/provider/messages"
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-gray-50">
      <div class="max-w-2xl mx-auto w-full flex flex-col h-full bg-white shadow-sm">
        <!-- Header -->
        <header class="sticky top-0 z-10 bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-3">
          <.link navigate={@back_path} class="text-gray-500 hover:text-gray-700">
            <.icon name="hero-arrow-left" class="w-6 h-6" />
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
    """
  end
end

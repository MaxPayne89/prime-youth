defmodule KlassHeroWeb.Provider.MessagesLive.Show do
  @moduledoc """
  LiveView for displaying a conversation with messages (provider view).

  Similar to the parent version but with provider-specific navigation.
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHeroWeb.MessagingLiveHelper

  require Logger

  @impl true
  def mount(%{"id" => conversation_id}, _session, socket) do
    MessagingLiveHelper.mount_conversation_show(socket, conversation_id,
      back_path: ~p"/provider/messages"
    )
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
    <div class="flex flex-col h-screen bg-gray-50">
      <div class="max-w-2xl mx-auto w-full flex flex-col h-full bg-white shadow-sm">
        <!-- Header -->
        <header class="sticky top-0 z-10 bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-3">
          <.link navigate={@back_path} class="text-gray-500 hover:text-gray-700">
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

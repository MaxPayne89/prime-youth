defmodule KlassHeroWeb.Provider.MessagesLive.Index do
  @moduledoc """
  LiveView for displaying the provider's conversation list.

  Similar to the parent version but includes provider-specific navigation.
  """

  use KlassHeroWeb, :live_view

  import KlassHeroWeb.MessagingComponents

  alias KlassHero.Shared.Domain.Events.DomainEvent
  alias KlassHeroWeb.MessagingLiveHelper

  @impl true
  def mount(_params, _session, socket) do
    MessagingLiveHelper.mount_conversation_index(socket, navigate_base: "/provider/messages")
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
            navigate={@navigate_base <> "/" <> conv_data.conversation.id}
          />
          <div :if={@conversations_empty?} id="conversations-empty-state" class="p-4">
            <.conversations_empty_state user_type={:provider} />
          </div>
        </div>
      </div>
    </div>
    """
  end
end

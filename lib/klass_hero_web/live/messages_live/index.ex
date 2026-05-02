defmodule KlassHeroWeb.MessagesLive.Index do
  @moduledoc """
  LiveView for displaying the user's conversation list (parent view).

  Features:
  - Lists all conversations with unread counts
  - Real-time updates via PubSub
  - Stream-based collection for memory efficiency
  """

  use KlassHeroWeb, :live_view
  use KlassHeroWeb.MessagingLiveHelper, :index

  import KlassHeroWeb.MessagingComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket} = MessagingLiveHelper.mount_conversation_index(socket, navigate_base: "/messages")
    {:ok, assign(socket, active_nav: :messages, page_title: gettext("Messages"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.conversation_index
      variant={:parent}
      streams={@streams}
      conversations_empty?={@conversations_empty?}
      navigate_base={@navigate_base}
    />
    """
  end
end

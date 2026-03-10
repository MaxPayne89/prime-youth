defmodule KlassHeroWeb.Provider.MessagesLive.Index do
  @moduledoc """
  LiveView for displaying the provider's conversation list.

  Shares layout and behavior with the parent version via
  `MessagingComponents.conversation_index/1` with `:provider` variant.
  """

  use KlassHeroWeb, :live_view
  use KlassHeroWeb.MessagingLiveHelper, :index

  import KlassHeroWeb.MessagingComponents

  @impl true
  def mount(_params, _session, socket) do
    MessagingLiveHelper.mount_conversation_index(socket, navigate_base: "/provider/messages")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.conversation_index
      variant={:provider}
      streams={@streams}
      conversations_empty?={@conversations_empty?}
      navigate_base={@navigate_base}
    />
    """
  end
end

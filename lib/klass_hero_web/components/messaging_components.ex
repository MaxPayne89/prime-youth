defmodule KlassHeroWeb.MessagingComponents do
  @moduledoc """
  UI components for the messaging system.

  Provides reusable components for:
  - Conversation list cards
  - Message bubbles
  - Empty states
  - Input forms
  """

  use Phoenix.Component
  use Gettext, backend: KlassHeroWeb.Gettext

  alias KlassHeroWeb.Theme

  @doc """
  Renders a conversation card for the conversation list.

  ## Attributes
  - id: DOM id for the card
  - conversation: The conversation entity
  - unread_count: Number of unread messages
  - latest_message: The most recent message (optional)
  - other_participant_name: Name of the other participant
  - on_click: Click handler

  ## Examples

      <.conversation_card
        id="conv-123"
        conversation={conv}
        unread_count={2}
        latest_message={message}
        other_participant_name="John Smith"
      />

  """
  attr :id, :string, required: true
  attr :conversation, :map, required: true
  attr :unread_count, :integer, default: 0
  attr :latest_message, :map, default: nil
  attr :other_participant_name, :string, default: "Unknown"
  attr :navigate, :string, default: nil

  def conversation_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      id={@id}
      class={[
        "block p-4 hover:bg-hero-grey-50 transition-colors",
        @unread_count > 0 && "bg-hero-blue-50"
      ]}
    >
      <div class="flex items-start gap-3">
        <!-- Avatar -->
        <div class={[
          "w-12 h-12 rounded-full flex items-center justify-center text-white font-semibold text-lg flex-shrink-0",
          avatar_color(@other_participant_name)
        ]}>
          {String.first(@other_participant_name) |> String.upcase()}
        </div>
        
    <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between gap-2">
            <h3 class={[
              "text-base truncate",
              @unread_count > 0 && ["font-semibold", Theme.text_color(:heading)],
              @unread_count == 0 && ["font-medium", Theme.text_color(:body)]
            ]}>
              {@other_participant_name}
            </h3>
            <span class={["text-xs flex-shrink-0", Theme.text_color(:muted)]}>
              {format_timestamp(@latest_message && @latest_message.inserted_at)}
            </span>
          </div>

          <div class="flex items-center justify-between gap-2 mt-1">
            <p class={[
              "text-sm truncate",
              @unread_count > 0 && Theme.text_color(:body),
              @unread_count == 0 && Theme.text_color(:muted)
            ]}>
              {preview_content(@latest_message)}
            </p>
            <.unread_badge :if={@unread_count > 0} count={@unread_count} />
          </div>

          <.broadcast_badge :if={@conversation.type == :program_broadcast} />
        </div>
      </div>
    </.link>
    """
  end

  @doc """
  Renders an unread message count badge.
  """
  attr :count, :integer, required: true

  def unread_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center justify-center min-w-5 h-5 px-1.5 text-xs font-semibold text-white bg-prime-magenta-500 rounded-full">
      {min(@count, 99)}
    </span>
    """
  end

  @doc """
  Renders a broadcast indicator badge.
  """
  attr :class, :string, default: nil

  def broadcast_badge(assigns) do
    ~H"""
    <span class={["inline-flex items-center gap-1 mt-1 text-xs", @class || "text-prime-cyan-600"]}>
      <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"
        />
      </svg>
      {gettext("Broadcast")}
    </span>
    """
  end

  @doc """
  Renders a message bubble.

  ## Attributes
  - id: DOM id
  - message: The message entity
  - is_own: Whether the current user sent this message
  - sender_name: Name of the sender

  """
  attr :id, :string, required: true
  attr :message, :map, required: true
  attr :is_own, :boolean, default: false
  attr :sender_name, :string, default: "Unknown"

  def message_bubble(assigns) do
    ~H"""
    <div id={@id} class={["flex", @is_own && "justify-end", !@is_own && "justify-start"]}>
      <div class={[
        "max-w-[80%] rounded-2xl px-4 py-2",
        @is_own && "bg-prime-cyan-500 text-white rounded-br-sm",
        !@is_own && [Theme.bg(:light), Theme.text_color(:heading), "rounded-bl-sm"]
      ]}>
        <p
          :if={!@is_own && @message.message_type != :system}
          class={["text-xs font-medium mb-1", Theme.text_color(:muted)]}
        >
          {@sender_name}
        </p>
        <p
          :if={@message.message_type == :system}
          class={["text-xs italic text-center", Theme.text_color(:muted)]}
        >
          {@message.content}
        </p>
        <p :if={@message.message_type != :system} class="text-sm whitespace-pre-wrap break-words">
          {@message.content}
        </p>
        <p class={[
          "text-xs mt-1",
          @is_own && "text-prime-cyan-100",
          !@is_own && Theme.text_color(:subtle)
        ]}>
          {format_message_time(@message.inserted_at)}
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Renders a message input form.
  """
  attr :form, :map, required: true
  attr :disabled, :boolean, default: false

  def message_input(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-submit="send_message"
      id="message-form"
      class={["flex items-end gap-2 p-4 border-t", Theme.border_color(:light), Theme.bg(:surface)]}
    >
      <div class="flex-1">
        <textarea
          name="content"
          id="message-input"
          rows="1"
          class={[
            "w-full px-4 py-2 border resize-none focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:border-transparent",
            Theme.border_color(:medium),
            Theme.rounded(:full)
          ]}
          placeholder={gettext("Type a message...")}
          phx-hook="AutoResizeTextarea"
          disabled={@disabled}
        >{Phoenix.HTML.Form.input_value(@form, :content)}</textarea>
      </div>
      <button
        type="submit"
        disabled={@disabled}
        class={[
          "w-10 h-10 flex items-center justify-center bg-hero-blue-600 text-white hover:bg-hero-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed",
          Theme.rounded(:full)
        ]}
      >
        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
          />
        </svg>
      </button>
    </.form>
    """
  end

  @doc """
  Renders the messages empty state.
  """
  def messages_empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-64 text-center px-4">
      <div class={["w-16 h-16 mb-4", Theme.text_color(:subtle)]}>
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
          />
        </svg>
      </div>
      <h3 class={["text-lg font-medium", Theme.text_color(:heading)]}>
        {gettext("No messages yet")}
      </h3>
      <p class={["mt-1 text-sm", Theme.text_color(:muted)]}>
        {gettext("Send a message to start the conversation")}
      </p>
    </div>
    """
  end

  @doc """
  Renders the conversations empty state.

  ## Attributes
  - user_type: Either :parent or :provider to show appropriate copy
  """
  attr :user_type, :atom, default: :parent

  def conversations_empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-64 text-center px-4">
      <div class={["w-16 h-16 mb-4", Theme.text_color(:subtle)]}>
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
          />
        </svg>
      </div>
      <h3 class={["text-lg font-medium", Theme.text_color(:heading)]}>
        {gettext("No conversations yet")}
      </h3>
      <p class={["mt-1 text-sm", Theme.text_color(:muted)]}>
        {empty_state_message(@user_type)}
      </p>
    </div>
    """
  end

  defp empty_state_message(:provider),
    do: gettext("Your conversations with parents will appear here")

  defp empty_state_message(_parent),
    do: gettext("Your conversations with providers will appear here")

  # Helpers

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

  defp format_timestamp(nil), do: ""

  defp format_timestamp(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> gettext("Now")
      diff < 3600 -> gettext("%{n}m ago", n: div(diff, 60))
      diff < 86_400 -> Calendar.strftime(datetime, "%H:%M")
      diff < 604_800 -> Calendar.strftime(datetime, "%a")
      true -> Calendar.strftime(datetime, "%d %b")
    end
  end

  defp format_message_time(nil), do: ""
  defp format_message_time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp preview_content(nil), do: gettext("No messages yet")
  defp preview_content(%{content: content}), do: String.slice(content, 0, 50)
end

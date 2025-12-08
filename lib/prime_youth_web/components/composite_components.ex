defmodule PrimeYouthWeb.CompositeComponents do
  @moduledoc """
  Provides composite UI components for Prime Youth application.

  This module contains larger, more complex components that compose together
  atomic components from UIComponents to create cohesive interface elements.
  """
  use Phoenix.Component

  import PrimeYouthWeb.UIComponents

  alias PrimeYouthWeb.Theme

  @doc """
  Renders a settings menu item with icon, title, description, and chevron.

  ## Examples

      <.settings_menu_item
        icon="hero-user"
        icon_bg={Theme.bg(:primary_light)}
        icon_color={Theme.text_color(:primary)}
        title="Profile Information"
        description="Name, email, profile photo"
        phx-click="navigate_to"
        phx-value-section="profile-information"
      />
  """
  attr :icon, :string, required: true, doc: "Heroicon name"
  attr :icon_bg, :string, required: true, doc: "Background color class for icon"
  attr :icon_color, :string, required: true, doc: "Text color class for icon"
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def settings_menu_item(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "w-full flex items-center gap-4 p-4 hover:bg-gray-50",
        Theme.transition(:normal),
        "border-b border-gray-100 last:border-b-0",
        @class
      ]}
      {@rest}
    >
      <.gradient_icon gradient_class={@icon_bg} size="sm" shape="circle" class="flex-shrink-0">
        <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
      </.gradient_icon>
      <div class="flex-1 text-left">
        <div class="font-medium text-gray-900">{@title}</div>
        <div class="text-sm text-gray-500">{@description}</div>
      </div>
      <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400 flex-shrink-0" />
    </button>
    """
  end

  @doc """
  Renders a child profile card with progress and activities.

  ## Examples

      <.child_card
        name="Emma Johnson"
        age={8}
        school="Greenwood Elementary"
        sessions="8/10"
        progress={80}
        activities={["Art", "Chess", "Swimming"]}
      />
  """
  attr :name, :string, required: true
  attr :age, :integer, required: true
  attr :school, :string, required: true
  attr :sessions, :string, required: true, doc: "Format: '8/10'"
  attr :progress, :integer, required: true, doc: "Progress percentage (0-100)"
  attr :activities, :list, required: true, doc: "List of activity names"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def child_card(assigns) do
    ~H"""
    <.card padding="p-4" class={"hover:shadow-md #{Theme.transition(:normal)} #{@class}"} {@rest}>
      <:body>
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <h4 class={[Theme.typography(:card_title), "text-gray-900"]}>{@name}</h4>
            <p class="text-sm text-gray-600">{@age} years old • {@school}</p>
          </div>
          <div class="text-right">
            <div class="text-sm font-medium text-gray-900">{@sessions}</div>
            <div class="text-xs text-gray-500">Sessions</div>
          </div>
        </div>
        <.progress_bar label="Progress" percentage={@progress} class="mb-3" />
        <div class="flex flex-wrap gap-1">
          <.status_pill
            :for={activity <- @activities}
            color="custom"
            class="bg-gray-100 text-gray-700"
          >
            {activity}
          </.status_pill>
        </div>
      </:body>
    </.card>
    """
  end

  @doc """
  Renders a quick action button with icon and label.

  ## Examples

      <.quick_action_button
        icon="hero-calendar"
        label="Book Activity"
        bg_color={Theme.bg(:primary_light)}
        icon_color={Theme.text_color(:primary)}
        phx-click="book_activity"
      />
  """
  attr :icon, :string, required: true, doc: "Heroicon name"
  attr :label, :string, required: true
  attr :bg_color, :string, required: true, doc: "Background color for icon container"
  attr :icon_color, :string, required: true, doc: "Icon color"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def quick_action_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "bg-white p-4 shadow-sm border border-gray-100",
        Theme.rounded(:xl),
        "hover:shadow-md hover:scale-[1.02]",
        Theme.transition(:normal),
        "group",
        @class
      ]}
      {@rest}
    >
      <.gradient_icon
        gradient_class={@bg_color}
        size="sm"
        shape="circle"
        class={"mb-3 group-hover:#{String.replace(@bg_color, "100", "200")} #{Theme.transition(:normal)}"}
      >
        <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
      </.gradient_icon>
      <div class="text-sm font-medium text-gray-900">{@label}</div>
    </button>
    """
  end

  @doc """
  Renders an upcoming activity card.

  ## Examples

      <.activity_card
        status="Today"
        status_color="bg-red-100 text-red-700"
        time="Today, 4:00 PM"
        name="Creative Art World"
        instructor="Ms. Rodriguez"
      />
  """
  attr :status, :string, required: true
  attr :status_color, :string, required: true, doc: "Custom color class for status badge"
  attr :time, :string, required: true
  attr :name, :string, required: true
  attr :instructor, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def activity_card(assigns) do
    ~H"""
    <.card padding="p-4" class={"hover:shadow-md #{Theme.transition(:normal)} #{@class}"} {@rest}>
      <:body>
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center mb-2">
              <.status_pill color="custom" class={@status_color}>
                {@status}
              </.status_pill>
              <span class="ml-2 text-sm text-gray-600">{@time}</span>
            </div>
            <h4 class={[Theme.typography(:card_title), "text-gray-900 mb-1"]}>{@name}</h4>
            <p class="text-sm text-gray-600">Instructor: {@instructor}</p>
          </div>
          <.gradient_icon gradient_class="bg-gray-100" size="sm" shape="circle" class="flex-shrink-0">
            <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-500" />
          </.gradient_icon>
        </div>
      </:body>
    </.card>
    """
  end

  @doc """
  Renders a payment option radio button with title and description.

  ## Examples

      <.payment_option
        value="card"
        title="Credit Card"
        description="Pay securely with Visa, Mastercard, or other cards"
        selected={@payment_method == "card"}
        phx-click="select_payment_method"
        phx-value-method="card"
      />
  """
  attr :value, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :selected, :boolean, required: true
  attr :name, :string, default: "payment_method"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def payment_option(assigns) do
    ~H"""
    <label class={[
      "flex items-start gap-3 p-4 border-2 cursor-pointer",
      Theme.transition(:normal),
      Theme.rounded(:lg),
      if(@selected,
        do: [Theme.border_color(:primary), Theme.bg(:primary_light)],
        else: "border-gray-200 hover:border-gray-300"
      ),
      @class
    ]}>
      <input
        type="radio"
        name={@name}
        value={@value}
        checked={@selected}
        class="mt-1"
        {@rest}
      />
      <div>
        <div class={[Theme.typography(:card_title), "text-gray-800"]}>{@title}</div>
        <div class="text-sm text-gray-600">{@description}</div>
      </div>
    </label>
    """
  end

  @doc """
  Renders a social feed post card with author, content, likes, and comments.

  ## Examples

      <.social_post
        author="Ms. Sarah - Art Instructor"
        avatar_bg={Theme.bg(:primary)}
        avatar_emoji="👩‍🏫"
        timestamp="2 hours ago"
        content="Amazing creativity from our students today!"
        likes={12}
        comment_count={5}
        user_liked={false}
        post_id="post_1"
      >
        <:photo_content>
          <div class={["h-48 bg-gradient-to-br from-yellow-400/30 to-yellow-400/50 flex items-center justify-center text-5xl", Theme.rounded(:md)]}>
            🎨📸
          </div>
        </:photo_content>
        <:comments>
          <div class={["bg-gray-50 p-3 space-y-2", Theme.rounded(:md)]}>
            <div class="flex gap-2">
              <span class="font-semibold text-gray-800 text-sm">Parent Maria:</span>
              <span class="text-gray-600 text-sm">Emma loves this class!</span>
            </div>
          </div>
        </:comments>
      </.social_post>
  """
  attr :id, :string, required: true, doc: "DOM ID for the post element (required for streams)"
  attr :post_id, :string, required: true
  attr :author, :string, required: true
  attr :avatar_bg, :string, required: true
  attr :avatar_emoji, :string, required: true
  attr :timestamp, :string, required: true
  attr :content, :string, required: true
  attr :likes, :integer, required: true
  attr :comment_count, :integer, required: true
  attr :user_liked, :boolean, required: true
  attr :class, :string, default: ""

  slot :photo_content, doc: "Optional photo/media content"
  slot :event_content, doc: "Optional event details content"
  slot :comments, doc: "Optional comments preview"

  def social_post(assigns) do
    ~H"""
    <div id={@id} class={["card bg-white shadow-lg", @class]}>
      <div class="card-body p-4">
        <!-- Post Header -->
        <div class="flex items-center gap-3 mb-4">
          <.gradient_icon gradient_class={@avatar_bg} size="sm" shape="circle">
            {@avatar_emoji}
          </.gradient_icon>
          <div class="flex-1">
            <div class={[Theme.typography(:card_title), "text-gray-800"]}>{@author}</div>
            <div class="text-sm text-gray-500">{@timestamp}</div>
          </div>
        </div>
        
    <!-- Post Content -->
        <p class="text-gray-700 mb-4 leading-relaxed">
          {@content}
        </p>
        
    <!-- Photo/Event Content -->
        {render_slot(@photo_content)}
        {render_slot(@event_content)}
        
    <!-- Post Actions -->
        <div class="border-t border-gray-100 pt-4">
          <div class="flex gap-6 mb-3">
            <button
              phx-click="toggle_like"
              phx-value-post_id={@post_id}
              class={[
                "flex items-center gap-2",
                Theme.transition(:normal),
                if(@user_liked, do: "text-red-500", else: "text-gray-500 hover:text-red-500")
              ]}
            >
              <span class="text-xl">{if @user_liked, do: "❤️", else: "🤍"}</span>
              <span class="text-sm font-medium">{@likes}</span>
            </button>
            <button class={["flex items-center gap-2 text-gray-500 hover:text-prime-cyan-400", Theme.transition(:normal)]}>
              <span class="text-xl">💬</span>
              <span class="text-sm font-medium">{@comment_count}</span>
            </button>
          </div>
          
    <!-- Comments Preview -->
          {render_slot(@comments)}
          
    <!-- Add Comment Form -->
          <form phx-submit="add_comment" class="flex gap-2 mt-3">
            <input type="hidden" name="post_id" value={@post_id} />
            <input
              type="text"
              name="comment"
              placeholder="Write a comment..."
              class="flex-1 input input-bordered input-sm bg-white border-gray-300 focus:border-prime-cyan-400 focus:ring-1 focus:ring-prime-cyan-400"
              autocomplete="off"
            />
            <button
              type="submit"
              class={["btn btn-sm text-white border-0 hover:shadow-lg", Theme.gradient(:primary)]}
            >
              Post
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end

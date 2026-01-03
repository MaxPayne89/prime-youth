defmodule KlassHeroWeb.CompositeComponents do
  @moduledoc """
  Provides composite UI components for Klass Hero application.

  This module contains larger, more complex components that compose together
  atomic components from UIComponents to create cohesive interface elements.
  """
  use Phoenix.Component
  use Gettext, backend: KlassHeroWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: KlassHeroWeb.Endpoint,
    router: KlassHeroWeb.Router,
    statics: KlassHeroWeb.static_paths()

  import KlassHeroWeb.UIComponents

  alias KlassHeroWeb.Theme

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
        "w-full flex items-center gap-4 p-4 hover:bg-hero-grey-50",
        Theme.transition(:normal),
        "border-b border-hero-grey-200 last:border-b-0",
        @class
      ]}
      {@rest}
    >
      <.gradient_icon gradient_class={@icon_bg} size="sm" shape="circle" class="flex-shrink-0">
        <.icon name={@icon} class={"w-5 h-5 #{@icon_color}"} />
      </.gradient_icon>
      <div class="flex-1 text-left">
        <div class="font-medium text-hero-black">{@title}</div>
        <div class="text-sm text-hero-grey-500">{@description}</div>
      </div>
      <.icon name="hero-chevron-right" class="w-5 h-5 text-hero-grey-400 flex-shrink-0" />
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
            <h4 class={[Theme.typography(:card_title), "text-hero-black"]}>{@name}</h4>
            <p class="text-sm text-hero-grey-500">{@age} years old • {@school}</p>
          </div>
          <div class="text-right">
            <div class="text-sm font-medium text-hero-black">{@sessions}</div>
            <div class="text-xs text-hero-grey-400">{gettext("Sessions")}</div>
          </div>
        </div>
        <.progress_bar label={gettext("Progress")} percentage={@progress} class="mb-3" />
        <div class="flex flex-wrap gap-1">
          <.status_pill
            :for={activity <- @activities}
            color="custom"
            class="bg-hero-grey-100 text-hero-black-100"
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
        "bg-white p-4 shadow-sm border border-hero-grey-200",
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
      <div class="text-sm font-medium text-hero-black">{@label}</div>
    </button>
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
        else: "border-hero-grey-200 hover:border-hero-grey-300"
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
        <div class={[Theme.typography(:card_title), "text-hero-black"]}>{@title}</div>
        <div class="text-sm text-hero-grey-500">{@description}</div>
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
    <article
      id={@id}
      data-testid="social-post"
      data-post-id={@post_id}
      class={["card bg-white shadow-lg", @class]}
    >
      <div class="card-body p-4">
        <!-- Post Header -->
        <div class="flex items-center gap-3 mb-4">
          <.gradient_icon gradient_class={@avatar_bg} size="sm" shape="circle">
            {@avatar_emoji}
          </.gradient_icon>
          <div class="flex-1">
            <div data-testid="post-author" class={[Theme.typography(:card_title), "text-hero-black"]}>
              {@author}
            </div>
            <div class="text-sm text-hero-grey-400">{@timestamp}</div>
          </div>
        </div>
        
    <!-- Post Content -->
        <p data-testid="post-content" class="text-hero-black-100 mb-4 leading-relaxed">
          {@content}
        </p>
        
    <!-- Photo/Event Content -->
        {render_slot(@photo_content)}
        {render_slot(@event_content)}
        
    <!-- Post Actions -->
        <div class="border-t border-hero-grey-200 pt-4">
          <div class="flex gap-6 mb-3">
            <button
              data-testid="like-button"
              phx-click="toggle_like"
              phx-value-post_id={@post_id}
              class={[
                "flex items-center gap-2",
                Theme.transition(:normal),
                if(@user_liked, do: "text-red-500", else: "text-hero-grey-400 hover:text-red-500")
              ]}
            >
              <span class="text-xl">{if @user_liked, do: "❤️", else: "🤍"}</span>
              <span data-testid="like-count" class="text-sm font-medium">{@likes}</span>
            </button>
            <button class={[
              "flex items-center gap-2 text-hero-grey-400 hover:text-hero-blue-600",
              Theme.transition(:normal)
            ]}>
              <span class="text-xl">💬</span>
              <span data-testid="comment-count" class="text-sm font-medium">{@comment_count}</span>
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
              class="flex-1 input input-bordered input-sm bg-white border-hero-grey-300 focus:border-hero-blue-600 focus:ring-1 focus:ring-hero-blue-600"
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
    </article>
    """
  end

  @doc """
  Renders the application footer with links and social media icons.

  ## Examples

      <.app_footer />
  """
  def app_footer(assigns) do
    ~H"""
    <footer class="footer footer-center p-10 bg-hero-black text-hero-grey-300">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-8 w-full max-w-6xl">
        <div class="text-left">
          <h3 class="font-bold text-lg text-white mb-4">Klass Hero</h3>
          <p class="text-sm">
            {gettext("Building the future of youth education by connecting communities.")}
          </p>
        </div>

        <div class="text-left">
          <h4 class="font-semibold mb-4">{gettext("Quick Links")}</h4>
          <ul class="space-y-2 text-sm">
            <li><a href="#programs" class="link link-hover">{gettext("Programs")}</a></li>
            <li><a href="#about" class="link link-hover">{gettext("About Us")}</a></li>
            <li><a href="#contact" class="link link-hover">{gettext("Contact")}</a></li>
            <li><a href="#faq" class="link link-hover">{gettext("FAQ")}</a></li>
          </ul>
        </div>

        <div class="text-left">
          <h4 class="font-semibold mb-4">{gettext("Programs")}</h4>
          <ul class="space-y-2 text-sm">
            <li><a href="#afterschool" class="link link-hover">{gettext("Afterschool")}</a></li>
            <li><a href="#camps" class="link link-hover">{gettext("Summer Camps")}</a></li>
            <li><a href="#trips" class="link link-hover">{gettext("Class Trips")}</a></li>
            <li><a href="#enrichment" class="link link-hover">{gettext("Enrichment")}</a></li>
          </ul>
        </div>

        <div class="text-left">
          <h4 class="font-semibold mb-4">{gettext("Connect")}</h4>
          <div class="flex gap-2 mb-4">
            <a href="#facebook" class="btn btn-circle btn-sm btn-ghost">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
              </svg>
            </a>
            <a href="#instagram" class="btn btn-circle btn-sm btn-ghost">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 6.62 5.367 11.987 11.988 11.987 6.62 0 11.987-5.367 11.987-11.987C24.014 5.367 18.637.001 12.017.001zM8.449 16.988c-1.297 0-2.448-.611-3.197-1.559-.496-.629-.795-1.422-.795-2.278 0-2.073 1.684-3.757 3.757-3.757 2.073 0 3.757 1.684 3.757 3.757 0 2.073-1.684 3.757-3.757 3.757z" />
              </svg>
            </a>
          </div>
          <div class="text-sm">
            <p>Email: info@primeyouth.com</p>
            <p>Phone: (555) 123-4567</p>
          </div>
        </div>
      </div>

      <div class="border-t border-base-300 pt-6 mt-6 w-full">
        <p class="text-sm">&copy; 2025 Klass Hero. {gettext("All rights reserved.")}</p>
        <div class="flex gap-4 justify-center mt-2 text-xs">
          <.link navigate={~p"/privacy"} class="link link-hover">{gettext("Privacy Policy")}</.link>
          <span class="text-gray-400">•</span>
          <.link navigate={~p"/terms"} class="link link-hover">{gettext("Terms of Service")}</.link>
        </div>
      </div>
    </footer>
    """
  end
end

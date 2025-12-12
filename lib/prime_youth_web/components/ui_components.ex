defmodule PrimeYouthWeb.UIComponents do
  @moduledoc """
  Provides UI components for Prime Youth application.

  This module contains reusable UI components that follow the Prime Youth design system
  with custom gradients, rounded corners, and Tailwind utilities.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: PrimeYouthWeb.Endpoint,
    router: PrimeYouthWeb.Router,
    statics: PrimeYouthWeb.static_paths()

  alias PrimeYouthWeb.Theme

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "w-4 h-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a gradient icon container.

  A circular or rounded container with gradient background and an icon or emoji inside.
  Commonly used throughout the application for visual consistency.

  ## Examples

      <.gradient_icon gradient_class={Theme.gradient(:cool)} size="lg">
        🎨
      </.gradient_icon>

      <.gradient_icon gradient_class={Theme.bg(:secondary)} size="md" shape="rounded">
        <.icon name="hero-user" class="w-5 h-5 text-white" />
      </.gradient_icon>
  """
  attr :gradient_class, :string,
    required: true,
    doc: "Tailwind gradient or solid background class"

  attr :size, :string, default: "md", values: ~w(sm md lg xl), doc: "Size of the icon container"

  attr :shape, :string,
    default: "circle",
    values: ~w(circle rounded),
    doc: "Shape of the container"

  attr :class, :string, default: "", doc: "Additional CSS classes"
  slot :inner_block, required: true, doc: "Icon content (emoji or heroicon)"

  def gradient_icon(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-center",
      size_classes(@size),
      shape_classes(@shape),
      @gradient_class,
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp size_classes("sm"), do: "w-10 h-10 text-xl"
  defp size_classes("md"), do: "w-12 h-12 text-2xl"
  defp size_classes("lg"), do: "w-16 h-16 text-3xl"
  defp size_classes("xl"), do: "w-20 h-20 text-4xl lg:w-24 lg:h-24 lg:text-5xl"

  defp shape_classes("circle"), do: Theme.rounded(:full)
  defp shape_classes("rounded"), do: Theme.rounded(:lg)

  @doc """
  Renders a status pill/badge.

  Small colored pill with text, used for status indicators, tags, and labels.

  ## Examples

      <.status_pill color="success">5 spots left</.status_pill>
      <.status_pill color="warning">2 spots left</.status_pill>
      <.status_pill color="error">Full</.status_pill>
      <.status_pill color="info">Available</.status_pill>
      <.status_pill color="custom" class="bg-blue-100 text-blue-700">Today</.status_pill>
  """
  attr :color, :string, default: "info", values: ~w(success warning error info custom)
  attr :class, :string, default: "", doc: "Additional CSS classes (required when color='custom')"
  slot :inner_block, required: true

  def status_pill(assigns) do
    ~H"""
    <span class={[
      "px-2 py-1 text-xs font-medium",
      Theme.rounded(:full),
      color_classes(@color),
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp color_classes("success"), do: "bg-green-100 text-green-700"
  defp color_classes("warning"), do: "bg-orange-100 text-orange-700"
  defp color_classes("error"), do: "bg-red-100 text-red-700"
  defp color_classes("info"), do: "bg-blue-100 text-blue-700"
  defp color_classes("custom"), do: ""

  @doc """
  Renders a progress bar with label and percentage.

  ## Examples

      <.progress_bar label="Progress" percentage={80} color_class={Theme.bg(:primary)} />
      <.progress_bar label="Completion" percentage={65} color_class="bg-green-500" />
  """
  attr :label, :string, default: "Progress"
  attr :percentage, :integer, required: true, doc: "Progress percentage (0-100)"

  attr :color_class, :string,
    default: Theme.bg(:primary),
    doc: "Tailwind background color class for the progress bar"

  attr :class, :string, default: ""

  def progress_bar(assigns) do
    ~H"""
    <div class={@class}>
      <div class={["flex justify-between text-xs mb-1", Theme.text_color(:secondary)]}>
        <span>{@label}</span>
        <span>{@percentage}%</span>
      </div>
      <div class={["w-full h-2", Theme.rounded(:full), Theme.bg(:medium)]}>
        <div
          class={[@color_class, "h-2", Theme.transition(:slow), Theme.rounded(:full)]}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a circular back button with glassmorphism effect.

  Automatically uses browser back navigation when no custom click handler is provided.

  ## Examples

      <.back_button />  # Uses browser back navigation
      <.back_button on_click="back_to_programs" />  # Custom event handler
      <.back_button phx-click="go_back" class="ml-4" />  # Custom event handler
      <.back_button size={:lg} color="text-blue-600" />  # Large button with custom color
  """
  attr :size, :atom, default: :md, values: [:sm, :md, :lg], doc: "Button and icon size"
  attr :color, :string, default: "text-white", doc: "Icon color class"

  attr :use_browser_back, :boolean,
    default: true,
    doc: "Use browser back navigation when no phx-click provided"

  attr :on_click, :string, default: nil, doc: "Phoenix event name (deprecated, use phx-click)"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def back_button(assigns) do
    # Size mappings
    assigns = assign(assigns, :size_classes, back_button_size_classes(assigns.size))

    # Determine click behavior
    assigns =
      if assigns.use_browser_back && !assigns.rest[:"phx-click"] && !assigns.on_click do
        # Use browser back navigation via plain JavaScript onclick
        assigns
        |> assign(:use_browser_back_nav, true)
      else
        # Support backwards compatibility with on_click
        assigns =
          if assigns.on_click && !assigns.rest[:"phx-click"] do
            Map.put(assigns, :rest, Map.put(assigns.rest, :"phx-click", assigns.on_click))
          else
            assigns
          end

        assigns
        |> assign(:use_browser_back_nav, false)
      end

    ~H"""
    <button
      type="button"
      class={[
        @size_classes.padding,
        "bg-white shadow-sm",
        Theme.rounded(:full),
        "hover:bg-gray-50",
        Theme.transition(:normal),
        @class
      ]}
      onclick={if @use_browser_back_nav, do: "window.history.back(); return false;", else: nil}
      {@rest}
    >
      <.icon name="hero-arrow-left" class={"#{@size_classes.icon} #{@color}"} />
    </button>
    """
  end

  defp back_button_size_classes(:sm), do: %{icon: "w-4 h-4", padding: "p-1"}
  defp back_button_size_classes(:md), do: %{icon: "w-6 h-6", padding: "p-2"}
  defp back_button_size_classes(:lg), do: %{icon: "w-8 h-8", padding: "p-3"}

  @doc """
  Renders a section divider with centered text.

  Commonly used in forms to separate sections like "Or continue with".

  ## Examples

      <.section_divider text="Or continue with" />
      <.section_divider text="Or sign up with" class="my-6" />
      <.section_divider text="Or continue with" bg_color="bg-transparent" text_color="text-white/80" line_color="border-white/20" />
  """
  attr :text, :string, required: true
  attr :class, :string, default: ""

  attr :bg_color, :string,
    default: Theme.bg(:surface),
    doc: "Tailwind background color class for text background"

  attr :text_color, :string, default: Theme.text_color(:muted), doc: "Tailwind text color class"

  attr :line_color, :string,
    default: Theme.border_color(:light),
    doc: "Tailwind border color class"

  def section_divider(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <div class="absolute inset-0 flex items-center">
        <div class={["w-full border-t", @line_color]}></div>
      </div>
      <div class="relative flex justify-center text-sm">
        <span class={["px-2", @bg_color, @text_color]}>{@text}</span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a social login/signup button with provider icon.

  ## Examples

      <.social_button provider="google" on_click="social_login" />
      <.social_button provider="facebook" phx-click="social_signup" />
  """
  attr :provider, :string, required: true, values: ~w(google facebook)
  attr :on_click, :string, default: nil, doc: "Phoenix event name (deprecated, use phx-click)"
  attr :variant, :string, default: "light", values: ~w(light dark)
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def social_button(assigns) do
    # Support both on_click and phx-click
    assigns =
      if assigns.on_click && !assigns.rest[:"phx-click"] do
        Map.put(assigns, :rest, Map.put(assigns.rest, :"phx-click", assigns.on_click))
      else
        assigns
      end

    ~H"""
    <button
      type="button"
      class={[
        "flex justify-center items-center px-4 py-3",
        Theme.transition(:normal),
        Theme.rounded(:lg),
        button_variant_classes(@variant),
        @class
      ]}
      {@rest}
    >
      <%= if @provider == "google" do %>
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
          <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
          <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
          <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
          <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
        </svg>
      <% end %>
      <%= if @provider == "facebook" do %>
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
        </svg>
      <% end %>
    </button>
    """
  end

  defp button_variant_classes("light") do
    [
      "border",
      Theme.border_color(:medium),
      Theme.text_color(:body),
      "hover:#{Theme.bg(:muted)}"
    ]
    |> Enum.join(" ")
  end

  defp button_variant_classes("dark") do
    "bg-white/10 border border-white/20 text-white hover:bg-white/20"
  end

  @doc """
  Renders an email icon for input fields.

  ## Examples

      <.email_icon color="text-white/60" />
      <.email_icon color={Theme.text_color(:subtle)} />
  """
  attr :color, :string, default: Theme.text_color(:subtle)
  attr :class, :string, default: ""

  def email_icon(assigns) do
    ~H"""
    <svg
      class={["w-5 h-5", @color, @class]}
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"
      >
      </path>
    </svg>
    """
  end

  @doc """
  Renders a password/eye icon for password input fields.

  ## Examples

      <.password_icon color="text-white/60" />
      <.password_icon color={Theme.text_color(:subtle)} />
  """
  attr :color, :string, default: Theme.text_color(:subtle)
  attr :class, :string, default: ""

  def password_icon(assigns) do
    ~H"""
    <svg
      class={["w-5 h-5", @color, @class]}
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
      >
      </path>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
      >
      </path>
    </svg>
    """
  end

  @doc """
  Renders an error alert box with icon and error messages.

  ## Examples

      <.error_alert errors={["Invalid email", "Password too short"]} />
      <.error_alert errors={@errors} />
  """
  attr :errors, :list, required: true
  attr :class, :string, default: ""

  def error_alert(assigns) do
    ~H"""
    <div
      :if={@errors != []}
      class={["mb-6 p-4 bg-red-50 border border-red-200", Theme.rounded(:md), @class]}
    >
      <div class="flex">
        <svg
          class="w-5 h-5 text-red-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          >
          </path>
        </svg>
        <div class="ml-3">
          <p :for={error <- @errors} class="text-sm text-red-700">{error}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a feature card with icon, title, and description.

  ## Examples

      <.feature_card
        gradient_class={Theme.gradient(:cool)}
        icon_path="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944..."
        title="Expert Instructors"
        description="All instructors are background-checked..."
      />
  """
  attr :gradient_class, :string, required: true
  attr :icon_path, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :class, :string, default: ""

  def feature_card(assigns) do
    ~H"""
    <div class={[
      "text-center group hover:transform hover:scale-105",
      Theme.transition(:normal),
      @class
    ]}>
      <div class={[
        "w-16 h-16 flex items-center justify-center mx-auto mb-6",
        Theme.rounded(:xl),
        "group-hover:shadow-lg",
        Theme.transition(:normal),
        @gradient_class
      ]}>
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon_path}></path>
        </svg>
      </div>
      <h3 class={[Theme.typography(:card_title), "mb-3", Theme.text_color(:heading)]}>{@title}</h3>
      <p class={Theme.text_color(:secondary)}>{@description}</p>
    </div>
    """
  end

  @doc """
  Renders a simple program card for homepage.

  ## Examples

      <.program_card_simple
        gradient_class={Theme.gradient(:art)}
        icon_path="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4..."
        title="Creative Art World"
        description="Unleash your child's creativity"
        price={45}
      />
  """
  attr :gradient_class, :string, required: true
  attr :icon_path, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :price, :integer, required: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def program_card_simple(assigns) do
    ~H"""
    <div
      class={[
        Theme.bg(:surface),
        Theme.rounded(:xl),
        "shadow-sm border",
        Theme.border_color(:light),
        "hover:shadow-lg overflow-hidden group cursor-pointer",
        Theme.transition(:slow),
        @class
      ]}
      {@rest}
    >
      <div class={["h-48 relative", @gradient_class]}>
        <div class={["absolute inset-0 bg-black/10 group-hover:bg-black/5", Theme.transition(:normal)]}>
        </div>
        <div class="absolute inset-0 flex items-center justify-center">
          <div class={[
            "w-20 h-20 bg-white/20 backdrop-blur-sm flex items-center justify-center",
            Theme.rounded(:full)
          ]}>
            <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon_path}>
              </path>
            </svg>
          </div>
        </div>
      </div>
      <div class="p-6">
        <h3 class={[Theme.typography(:card_title), "mb-2", Theme.text_color(:heading)]}>{@title}</h3>
        <p class={["text-sm mb-4 line-clamp-2", Theme.text_color(:secondary)]}>{@description}</p>
        <div class="flex items-center justify-between">
          <span class={[Theme.typography(:section_title), Theme.text_color(:secondary)]}>
            €{@price}
          </span>
          <span class={["text-sm", Theme.text_color(:muted)]}>per week</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a statistic display with large gradient number and label.

  ## Examples

      <.stat_display
        value="10,000+"
        label="Active Families"
        gradient_class={Theme.gradient(:primary)}
      />
  """
  attr :value, :string, required: true
  attr :label, :string, required: true
  attr :gradient_class, :string, required: true
  attr :class, :string, default: ""

  def stat_display(assigns) do
    ~H"""
    <div class={["text-center", @class]}>
      <div class={[
        Theme.typography(:hero),
        "bg-clip-text text-transparent mb-2",
        @gradient_class
      ]}>
        {@value}
      </div>
      <div class={Theme.text_color(:secondary)}>{@label}</div>
    </div>
    """
  end

  @doc """
  Renders an empty state with icon, title, description, and optional action.

  Displays a centered empty state with gray icon circle, title, and description.
  Commonly used when no results are found or when a list is empty.

  ## Examples

      <.empty_state
        icon_path="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        title="No programs found"
        description="Try adjusting your search or filter criteria."
      />

      <.empty_state
        icon_path="M12 4v16m8-8H4"
        title="No items yet"
        description="Get started by adding your first item."
      >
        <:action>
          <button class={["mt-4 px-4 py-2 bg-prime-cyan-400 text-white", Theme.rounded(:md)]}>
            Add Item
          </button>
        </:action>
      </.empty_state>
  """
  attr :icon_path, :string, required: true, doc: "SVG path data for the icon"
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :class, :string, default: ""
  attr :data_testid, :string, default: "empty-state", doc: "Test ID for testing"
  slot :action, doc: "Optional action button or link"

  def empty_state(assigns) do
    ~H"""
    <div data-testid={@data_testid} class={["text-center py-12", @class]}>
      <div class={[
        "w-16 h-16 flex items-center justify-center mx-auto mb-4",
        Theme.rounded(:full),
        Theme.bg(:light)
      ]}>
        <svg
          class={["w-8 h-8", Theme.text_color(:subtle)]}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d={@icon_path}
          >
          </path>
        </svg>
      </div>
      <h3 class={[Theme.typography(:card_title), "mb-2", Theme.text_color(:heading)]}>{@title}</h3>
      <p class={Theme.text_color(:secondary)}>{@description}</p>
      <div :if={@action != []}>
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a circular icon button with hover effects.

  Small, circular button with an icon, commonly used for actions like favorite,
  menu, close, etc. Supports different background variants.

  ## Examples

      <.icon_button icon_path="M6 18L18 6M6 6l12 12" aria_label="Close" phx-click="close" />

      <.icon_button
        icon_path="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2..."
        variant="light"
        phx-click="open_menu"
      />

      <.icon_button
        icon_path="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364..."
        variant="glass"
        class="text-red-500"
        phx-click="toggle_favorite"
      />
  """
  attr :icon_path, :string, required: true, doc: "SVG path data for the icon"

  attr :variant, :string,
    default: "light",
    values: ~w(light glass solid),
    doc: "Button background style"

  attr :aria_label, :string, default: nil, doc: "Accessibility label"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled type)

  def icon_button(assigns) do
    ~H"""
    <button
      type="button"
      aria-label={@aria_label}
      class={[
        "p-2",
        Theme.transition(:normal),
        Theme.rounded(:full),
        icon_button_variant(@variant),
        @class
      ]}
      {@rest}
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d={@icon_path}
        >
        </path>
      </svg>
    </button>
    """
  end

  defp icon_button_variant("light"), do: "#{Theme.bg(:light)} hover:#{Theme.bg(:medium)}"

  defp icon_button_variant("glass"),
    do: "#{Theme.bg(:surface)}/80 backdrop-blur-sm hover:#{Theme.bg(:surface)}"

  defp icon_button_variant("solid"),
    do: "#{Theme.bg(:surface)} hover:#{Theme.bg(:muted)} shadow-sm"

  @doc """
  Renders a page hero section with title, optional subtitle, and optional back button.

  **DEPRECATED**: Use `.hero_section` component instead with `variant="page"` for consistent hero patterns.

  Full-width hero section commonly used at the top of pages. Supports gradient backgrounds
  and can include a back button for navigation.

  ## Examples

      <.page_hero
        title="Programs"
        gradient_class={Theme.gradient(:hero)}
      />

      <.page_hero
        title="Enrollment"
        subtitle="Complete your program enrollment"
        show_back_button
        phx-click="back_to_programs"
      />
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :gradient_class, :string, default: Theme.bg(:surface)
  attr :show_back_button, :boolean, default: false
  attr :text_color, :string, default: Theme.text_color(:heading)
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def page_hero(assigns) do
    ~H"""
    <div class={[gradient_class(@gradient_class), "p-6 shadow-sm", @class]}>
      <div class="flex items-center gap-4 mb-4">
        <.back_button :if={@show_back_button} {@rest} />
        <div>
          <h1 class={[Theme.typography(:section_title), @text_color]}>{@title}</h1>
          <p :if={@subtitle} class={["text-sm mt-1", subtitle_color(@text_color)]}>{@subtitle}</p>
        </div>
      </div>
    </div>
    """
  end

  defp gradient_class("bg-white"), do: Theme.bg(:surface)
  defp gradient_class(class), do: class

  defp subtitle_color("text-white"), do: "text-white/80"
  defp subtitle_color("text-gray-900"), do: Theme.text_color(:secondary)
  defp subtitle_color(_), do: Theme.text_color(:secondary)

  @doc """
  Renders a unified hero section with multiple variant styles.

  This component unifies all hero section patterns in the application, from large landing page
  heroes to compact page headers. It supports three variants:

  - `variant="landing"` - Full marketing hero with logo, CTAs, and wave decoration
  - `variant="page"` - Compact page header with optional back button
  - `variant="minimal"` - Ultra-simple header with just title

  ## Examples

      # Landing page hero (home page style)
      <.hero_section variant="landing" show_logo>
        <:title>Prime Youth</:title>
        <:subtitle>Afterschool Adventures Await</:subtitle>
        <:actions>
          <button phx-click="get_started" class={["px-8 py-4 font-semibold", Theme.rounded(:lg), Theme.bg(:surface), Theme.text_color(:heading)]}>
            Get Started Free
          </button>
          <button phx-click="explore_programs" class={["px-8 py-4 bg-white/20 backdrop-blur-sm border-2 border-white text-white", Theme.rounded(:lg)]}>
            Explore Programs
          </button>
        </:actions>
      </.hero_section>

      # Page header (about/contact page style)
      <.hero_section
        variant="page"
        gradient_class={Theme.gradient(:hero)}
        show_back_button
        phx-click="back_to_home"
      >
        <:title>About Us</:title>
        <:subtitle>Learn more about Prime Youth</:subtitle>
      </.hero_section>

      # Minimal header
      <.hero_section variant="minimal">
        <:title>Settings</:title>
      </.hero_section>
  """
  attr :variant, :string,
    default: "page",
    values: ~w(landing page minimal),
    doc: "Hero style variant"

  attr :gradient_class, :string,
    default: Theme.gradient(:primary),
    doc: "Background gradient or solid color class"

  attr :show_logo, :boolean, default: false, doc: "Show animated logo (landing variant only)"
  attr :show_wave, :boolean, default: true, doc: "Show decorative wave (landing variant only)"

  attr :show_back_button, :boolean,
    default: false,
    doc: "Show back button (page variant only)"

  attr :back_button_size, :atom,
    default: :md,
    doc: "Back button size (:sm, :md, :lg)"

  attr :back_button_color, :string,
    default: "text-white",
    doc: "Back button icon color"

  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  slot :title, required: true, doc: "Hero title text"
  slot :subtitle, doc: "Optional subtitle text"
  slot :actions, doc: "Action buttons (landing variant only)"

  def hero_section(assigns) do
    ~H"""
    <div class={[
      "relative",
      variant_wrapper_classes(@variant),
      @variant == "landing" && "overflow-hidden",
      @variant == "landing" && @gradient_class,
      @variant != "landing" && @gradient_class,
      @class
    ]}>
      <%= if @variant == "landing" do %>
        <%!-- Landing page hero --%>
        <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 lg:py-32">
          <div class="text-center">
            <div
              :if={@show_logo}
              class={[
                "inline-flex items-center justify-center w-24 h-24 bg-white shadow-lg mb-8 animate-bounce-gentle",
                Theme.rounded(:full)
              ]}
            >
              <img
                src={~p"/images/logo-standard.png"}
                alt="Prime Youth Logo"
                class="w-16 h-16 object-contain"
              />
            </div>

            <h1 class={[Theme.typography(:hero), "text-white mb-4 animate-fade-in"]}>
              {render_slot(@title)}
            </h1>

            <p
              :if={@subtitle != []}
              class={[Theme.typography(:section_title), "text-white/90 mb-8 max-w-3xl mx-auto"]}
            >
              {render_slot(@subtitle)}
            </p>

            <div :if={@actions != []} class="flex flex-col sm:flex-row gap-4 justify-center">
              {render_slot(@actions)}
            </div>
          </div>
        </div>
        <%!-- Decorative Wave --%>
        <div :if={@show_wave} class="absolute bottom-0 left-0 right-0">
          <svg class="w-full h-16 fill-white" viewBox="0 0 1200 120" preserveAspectRatio="none">
            <path d="M321.39,56.44c58-10.79,114.16-30.13,172-41.86,82.39-16.72,168.19-17.73,250.45-.39C823.78,31,906.67,72,985.66,92.83c70.05,18.48,146.53,26.09,214.34,3V0H0V27.35A600.21,600.21,0,0,0,321.39,56.44Z">
            </path>
          </svg>
        </div>
      <% end %>

      <%= if @variant == "page" do %>
        <%!-- Page header --%>
        <div class="p-6">
          <div class="flex items-center gap-4 mb-4">
            <.back_button
              :if={@show_back_button}
              size={@back_button_size}
              color={@back_button_color}
              {@rest}
            />
            <div>
              <h1 class={[Theme.typography(:section_title), "text-white"]}>
                {render_slot(@title)}
              </h1>
              <p :if={@subtitle != []} class="text-sm mt-1 text-white/80">
                {render_slot(@subtitle)}
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @variant == "minimal" do %>
        <%!-- Minimal header --%>
        <div class="p-6">
          <h1 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
            {render_slot(@title)}
          </h1>
          <p :if={@subtitle != []} class={["text-sm mt-1", Theme.text_color(:secondary)]}>
            {render_slot(@subtitle)}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp variant_wrapper_classes("landing"), do: ""
  defp variant_wrapper_classes("page"), do: "shadow-sm"
  defp variant_wrapper_classes("minimal"), do: Theme.bg(:surface)

  @doc """
  Renders a unified page header with support for multiple layouts and styles.

  This component consolidates various header patterns used across LiveViews,
  providing consistent spacing, typography, and responsive behavior.

  ## Variants
  - `:white` - White background with dark text (default)
  - `:gradient` - Gradient background with white text

  ## Examples

      # Simple white header with title
      <.page_header>
        <:title>Programs</:title>
      </.page_header>

      # Gradient header with title and subtitle
      <.page_header variant={:gradient}>
        <:title>Settings</:title>
        <:subtitle>Manage your account and preferences</:subtitle>
      </.page_header>

      # Header with profile section (Dashboard)
      <.page_header variant={:gradient} rounded>
        <:profile>
          <img src={@user.avatar} class={["w-12 h-12", Theme.rounded(:full)]} />
          <div>
            <h2 class={Theme.typography(:card_title)}>{@user.name}</h2>
            <p class={[Theme.typography(:body_small), "text-white/80"]}>{length(@children)} children enrolled</p>
          </div>
        </:profile>
        <:actions>
          <button>Settings</button>
        </:actions>
      </.page_header>

      # Header with back button
      <.page_header variant={:gradient} show_back_button>
        <:title>Enrollment</:title>
      </.page_header>

      # Header with action buttons
      <.page_header>
        <:title>Programs</:title>
        <:actions>
          <button class="p-2">More options</button>
        </:actions>
      </.page_header>
  """
  attr :variant, :atom, default: :white, values: [:white, :gradient]

  attr :gradient_class, :string, default: Theme.gradient(:primary)

  attr :rounded, :boolean, default: false, doc: "Apply rounded-b-3xl style for Dashboard"
  attr :show_back_button, :boolean, default: false

  attr :container_class, :string,
    default: nil,
    doc: "Custom container class (e.g., max-w-4xl mx-auto)"

  attr :class, :string, default: nil
  attr :rest, :global

  slot :title, doc: "Main header title (required unless using :profile slot)"
  slot :subtitle
  slot :profile, doc: "Profile section with avatar and user info (alternative to :title)"
  slot :actions, doc: "Action buttons (settings, notifications, more options)"

  def page_header(assigns) do
    ~H"""
    <div class={[
      "p-6",
      @variant == :gradient && [@gradient_class, "text-white"],
      @variant == :white && "#{Theme.bg(:surface)} shadow-sm",
      @rounded && "rounded-b-3xl",
      @class
    ]}>
      <div class={[@container_class]}>
        <%= if @profile != [] and @title == [] do %>
          <%!-- Profile layout (Dashboard) --%>
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              {render_slot(@profile)}
            </div>

            <div :if={@actions != []} class="flex space-x-2">
              {render_slot(@actions)}
            </div>
          </div>
        <% else %>
          <%!-- Standard title layout --%>
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-4">
              <.back_button :if={@show_back_button} {@rest} />
              <div>
                <h1 class={[
                  Theme.typography(:section_title),
                  @variant == :white && Theme.text_color(:heading),
                  @variant == :gradient && "text-white"
                ]}>
                  {render_slot(@title)}
                </h1>
                <p
                  :if={@subtitle != []}
                  class={[
                    "text-sm mt-1",
                    @variant == :white && Theme.text_color(:secondary),
                    @variant == :gradient && "text-white/80"
                  ]}
                >
                  {render_slot(@subtitle)}
                </p>
              </div>
            </div>

            <div :if={@actions != []} class="flex space-x-2">
              {render_slot(@actions)}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a generic card container with flexible content slots.

  This is a foundational component for creating consistent card layouts throughout
  the application. Use slots for maximum flexibility in card content composition.

  ## Examples

      # Simple card with body only
      <.card>
        <:body>
          <p>Card content here</p>
        </:body>
      </.card>

      # Card with header, body, and footer
      <.card variant={:elevated}>
        <:header>
          <h3>Card Title</h3>
        </:header>
        <:body>
          <p>Main content here</p>
        </:body>
        <:footer>
          <button>Action</button>
        </:footer>
      </.card>

      # Clickable card with custom padding
      <.card padding="p-4" phx-click="select_item" phx-value-id={@item.id}>
        <:body>
          <p>Clickable content</p>
        </:body>
      </.card>
  """
  attr :variant, :atom, default: :default, values: [:default, :elevated, :outlined]
  attr :padding, :string, default: "p-6"
  attr :class, :string, default: ""
  slot :header
  slot :body, required: true
  slot :footer
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def card(assigns) do
    ~H"""
    <div
      class={[
        Theme.bg(:surface),
        Theme.rounded(:xl),
        card_variant_classes(@variant),
        @padding,
        @class
      ]}
      {@rest}
    >
      <div :if={@header != []} class={["border-b pb-4 mb-4", Theme.border_color(:light)]}>
        {render_slot(@header)}
      </div>

      <div>
        {render_slot(@body)}
      </div>

      <div :if={@footer != []} class={["border-t pt-4 mt-4", Theme.border_color(:light)]}>
        {render_slot(@footer)}
      </div>
    </div>
    """
  end

  defp card_variant_classes(:default), do: "shadow-sm border #{Theme.border_color(:light)}"
  defp card_variant_classes(:elevated), do: "shadow-lg"
  defp card_variant_classes(:outlined), do: "border-2 #{Theme.border_color(:medium)}"
end

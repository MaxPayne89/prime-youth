defmodule PrimeYouthWeb.UIComponents do
  @moduledoc """
  Provides UI components for Prime Youth application.

  This module contains reusable UI components that follow the Prime Youth design system
  with custom gradients, rounded corners, and Tailwind utilities.
  """
  use Phoenix.Component

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

      <.gradient_icon gradient_class="bg-gradient-to-br from-prime-cyan-400 to-blue-500" size="lg">
        🎨
      </.gradient_icon>

      <.gradient_icon gradient_class="bg-prime-magenta-400" size="md" shape="rounded">
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

  defp shape_classes("circle"), do: "rounded-full"
  defp shape_classes("rounded"), do: "rounded-xl"

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
      "px-2 py-1 rounded-full text-xs font-medium",
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

      <.progress_bar label="Progress" percentage={80} color_class="bg-prime-cyan-400" />
      <.progress_bar label="Completion" percentage={65} color_class="bg-green-500" />
  """
  attr :label, :string, default: "Progress"
  attr :percentage, :integer, required: true, doc: "Progress percentage (0-100)"

  attr :color_class, :string,
    default: "bg-prime-cyan-400",
    doc: "Tailwind background color class for the progress bar"

  attr :class, :string, default: ""

  def progress_bar(assigns) do
    ~H"""
    <div class={@class}>
      <div class="flex justify-between text-xs text-gray-600 mb-1">
        <span>{@label}</span>
        <span>{@percentage}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div
          class={[@color_class, "h-2 rounded-full transition-all duration-300"]}
          style={"width: #{@percentage}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a circular back button with glassmorphism effect.

  ## Examples

      <.back_button on_click="back_to_programs" />
      <.back_button phx-click="go_back" class="ml-4" />
  """
  attr :on_click, :string, default: nil, doc: "Phoenix event name (deprecated, use phx-click)"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-* disabled)

  def back_button(assigns) do
    # Support both on_click and phx-click for backwards compatibility
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
        "p-2 bg-white/20 backdrop-blur-sm rounded-full",
        "hover:bg-white/30 transition-colors",
        @class
      ]}
      {@rest}
    >
      <.icon name="hero-arrow-left" class="w-6 h-6 text-white" />
    </button>
    """
  end

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
    default: "bg-white",
    doc: "Tailwind background color class for text background"

  attr :text_color, :string, default: "text-gray-500", doc: "Tailwind text color class"
  attr :line_color, :string, default: "border-gray-200", doc: "Tailwind border color class"

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
        "flex justify-center items-center px-4 py-3 rounded-xl transition-all",
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
    "border border-gray-300 text-gray-700 hover:bg-gray-50"
  end

  defp button_variant_classes("dark") do
    "bg-white/10 border border-white/20 text-white hover:bg-white/20"
  end

  @doc """
  Renders an email icon for input fields.

  ## Examples

      <.email_icon color="text-white/60" />
      <.email_icon color="text-gray-400" />
  """
  attr :color, :string, default: "text-gray-400"
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
      <.password_icon color="text-gray-400" />
  """
  attr :color, :string, default: "text-gray-400"
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
    <div :if={@errors != []} class={["mb-6 p-4 bg-red-50 border border-red-200 rounded-lg", @class]}>
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
        gradient_class="bg-gradient-to-br from-prime-cyan-400 to-blue-500"
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
      "text-center group hover:transform hover:scale-105 transition-all duration-200",
      @class
    ]}>
      <div class={[
        "w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-6",
        "group-hover:shadow-lg transition-shadow",
        @gradient_class
      ]}>
        <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon_path}></path>
        </svg>
      </div>
      <h3 class="text-xl font-semibold text-gray-900 mb-3">{@title}</h3>
      <p class="text-gray-600">{@description}</p>
    </div>
    """
  end

  @doc """
  Renders a simple program card for homepage.

  ## Examples

      <.program_card_simple
        gradient_class="bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600"
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
        "bg-white rounded-2xl shadow-sm border border-gray-100",
        "hover:shadow-lg transition-all duration-300 overflow-hidden group cursor-pointer",
        @class
      ]}
      {@rest}
    >
      <div class={["h-48 relative", @gradient_class]}>
        <div class="absolute inset-0 bg-black/10 group-hover:bg-black/5 transition-colors"></div>
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="w-20 h-20 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
            <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={@icon_path}>
              </path>
            </svg>
          </div>
        </div>
      </div>
      <div class="p-6">
        <h3 class="text-xl font-bold text-gray-900 mb-2">{@title}</h3>
        <p class="text-gray-600 text-sm mb-4 line-clamp-2">{@description}</p>
        <div class="flex items-center justify-between">
          <span class="text-2xl font-bold text-prime-magenta-400">€{@price}</span>
          <span class="text-sm text-gray-500">per week</span>
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
        gradient_class="bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"
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
        "text-4xl md:text-5xl font-bold bg-clip-text text-transparent mb-2",
        @gradient_class
      ]}>
        {@value}
      </div>
      <div class="text-gray-600">{@label}</div>
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
          <button class="mt-4 px-4 py-2 bg-prime-cyan-400 text-white rounded-lg">
            Add Item
          </button>
        </:action>
      </.empty_state>
  """
  attr :icon_path, :string, required: true, doc: "SVG path data for the icon"
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :class, :string, default: ""
  slot :action, doc: "Optional action button or link"

  def empty_state(assigns) do
    ~H"""
    <div class={["text-center py-12", @class]}>
      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d={@icon_path}
          >
          </path>
        </svg>
      </div>
      <h3 class="text-lg font-semibold text-gray-900 mb-2">{@title}</h3>
      <p class="text-gray-600">{@description}</p>
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
        "p-2 rounded-full transition-colors",
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

  defp icon_button_variant("light"), do: "bg-gray-100 hover:bg-gray-200"
  defp icon_button_variant("glass"), do: "bg-white/80 backdrop-blur-sm hover:bg-white"
  defp icon_button_variant("solid"), do: "bg-white hover:bg-gray-50 shadow-sm"

  @doc """
  Renders a page hero section with title, optional subtitle, and optional back button.

  Full-width hero section commonly used at the top of pages. Supports gradient backgrounds
  and can include a back button for navigation.

  ## Examples

      <.page_hero
        title="Programs"
        gradient_class="bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400"
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
  attr :gradient_class, :string, default: "bg-white"
  attr :show_back_button, :boolean, default: false
  attr :text_color, :string, default: "text-gray-900"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def page_hero(assigns) do
    ~H"""
    <div class={[gradient_class(@gradient_class), "p-6 shadow-sm", @class]}>
      <div class="flex items-center gap-4 mb-4">
        <.back_button :if={@show_back_button} {@rest} />
        <div>
          <h1 class={["text-2xl md:text-3xl font-bold", @text_color]}>{@title}</h1>
          <p :if={@subtitle} class={["text-sm mt-1", subtitle_color(@text_color)]}>{@subtitle}</p>
        </div>
      </div>
    </div>
    """
  end

  defp gradient_class("bg-white"), do: "bg-white"
  defp gradient_class(class), do: class

  defp subtitle_color("text-white"), do: "text-white/80"
  defp subtitle_color("text-gray-900"), do: "text-gray-600"
  defp subtitle_color(_), do: "text-gray-600"
end

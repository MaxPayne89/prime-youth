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
  attr :gradient_class, :string, required: true, doc: "Tailwind gradient or solid background class"
  attr :size, :string, default: "md", values: ~w(sm md lg xl), doc: "Size of the icon container"
  attr :shape, :string, default: "circle", values: ~w(circle rounded), doc: "Shape of the container"
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
  attr :color_class, :string, default: "bg-prime-cyan-400", doc: "Tailwind background color class for the progress bar"
  attr :class, :string, default: ""

  def progress_bar(assigns) do
    ~H"""
    <div class={@class}>
      <div class="flex justify-between text-xs text-gray-600 mb-1">
        <span>{@label}</span>
        <span>{@percentage}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class={[@color_class, "h-2 rounded-full transition-all duration-300"]} style={"width: #{@percentage}%"}>
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
    assigns = if assigns.on_click && !assigns.rest[:"phx-click"] do
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
  """
  attr :text, :string, required: true
  attr :class, :string, default: ""
  attr :text_color, :string, default: "text-gray-500", doc: "Tailwind text color class"
  attr :line_color, :string, default: "border-gray-200", doc: "Tailwind border color class"

  def section_divider(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <div class="absolute inset-0 flex items-center">
        <div class={["w-full border-t", @line_color]}></div>
      </div>
      <div class="relative flex justify-center text-sm">
        <span class={["px-2 bg-white", @text_color]}>{@text}</span>
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
    assigns = if assigns.on_click && !assigns.rest[:"phx-click"] do
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
end

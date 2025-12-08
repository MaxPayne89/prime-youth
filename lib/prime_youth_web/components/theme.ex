defmodule PrimeYouthWeb.Theme do
  @moduledoc """
  Centralized theme utilities for Prime Youth design system.

  This module provides consistent access to gradients, colors, spacing, shadows,
  typography, and other design tokens used throughout the Prime Youth application.

  ## Design Tokens

  - **Colors**: Primary (cyan), Secondary (magenta), Accent (yellow)
  - **Gradients**: 15+ pre-defined gradients for various use cases
  - **Icon Styles**: Paired background + text colors for icons
  - **Status**: Color combinations for availability states
  - **Spacing**: Consistent scale from xs to 2xl
  - **Shadows**: None to xl shadow levels
  - **Typography**: Hero to caption text styles
  - **Rounded**: Border radius scale
  - **Transitions**: Animation duration presets

  ## Usage

      # In components:
      alias PrimeYouthWeb.Theme

      <div class={Theme.gradient(:primary)}>...</div>
      <div class={Theme.bg(:primary)}>...</div>
      <span class={Theme.text_color(:heading)}>Title</span>

      # Icon with background:
      {bg, text} = Theme.icon_styles(:primary)
      <div class={bg}><span class={text}>...</span></div>

      # Status badge:
      <span class={Theme.status(:available)}>Available</span>
  """

  # ============================================
  # GRADIENTS
  # ============================================

  @gradients %{
    # Primary brand gradients
    primary: "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400",
    hero: "bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400",
    magenta_yellow: "bg-gradient-to-r from-prime-magenta-400 to-prime-yellow-400",
    yellow_cyan: "bg-gradient-to-r from-prime-yellow-400 to-prime-cyan-400",

    # Warm gradients (yellows, oranges, reds)
    warm: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
    warm_intense: "bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600",
    warm_yellow: "bg-gradient-to-br from-prime-yellow-400 to-orange-500",

    # Cool gradients (blues, cyans, purples)
    cool: "bg-gradient-to-br from-prime-cyan-400 to-blue-500",
    cool_magenta: "bg-gradient-to-br from-prime-magenta-400 to-pink-500",
    cool_purple: "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600",

    # Nature gradients (greens)
    nature: "bg-gradient-to-br from-green-400 via-blue-500 to-purple-600",
    success: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
    safety: "bg-gradient-to-br from-green-400 to-emerald-500",

    # Neutral/Dark gradients
    dark: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
    tech: "bg-gradient-to-br from-blue-500 via-indigo-600 to-purple-700",

    # Default program gradient
    program_default: "bg-gradient-to-br from-blue-500 via-purple-500 to-pink-500",

    # Specialty gradients for specific program types
    art: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
    chess: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
    science: "bg-gradient-to-br from-green-400 via-blue-500 to-purple-600",
    sports: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",
    music: "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600",
    coding: "bg-gradient-to-br from-blue-500 via-indigo-600 to-purple-700"
  }

  @doc """
  Returns the gradient class for the specified gradient name.

  ## Available Gradients

  - `:primary` - Cyan to magenta horizontal
  - `:hero` - Full brand colors diagonal
  - `:warm` - Yellow to orange
  - `:cool` - Cyan to blue
  - `:success` - Green tones
  - `:art`, `:chess`, `:science`, `:sports`, `:music`, `:coding` - Program-specific

  ## Examples

      iex> Theme.gradient(:primary)
      "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"

      iex> Theme.gradient(:hero)
      "bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400"
  """
  def gradient(name) when is_atom(name) do
    Map.get(@gradients, name, @gradients.primary)
  end

  @doc "Returns all available gradient names."
  def available_gradients, do: Map.keys(@gradients)

  @doc "Returns a map of all gradients."
  def all_gradients, do: @gradients

  # ============================================
  # COLOR TOKENS
  # ============================================

  @colors %{
    primary: "prime-cyan",
    secondary: "prime-magenta",
    accent: "prime-yellow"
  }

  @doc """
  Returns the base color name for the specified color token.

  ## Examples

      iex> Theme.color(:primary)
      "prime-cyan"
  """
  def color(:primary), do: @colors.primary
  def color(:secondary), do: @colors.secondary
  def color(:accent), do: @colors.accent

  # ============================================
  # BACKGROUND CLASSES
  # ============================================

  @doc """
  Returns the background class for the specified variant.

  ## Variants

  - `:primary`, `:primary_light`, `:primary_dark` - Cyan shades
  - `:secondary`, `:secondary_light`, `:secondary_dark` - Magenta shades
  - `:accent`, `:accent_light` - Yellow shades
  - `:surface` - Default white background
  - `:muted` - Subtle gray background

  ## Examples

      iex> Theme.bg(:primary)
      "bg-prime-cyan-400"

      iex> Theme.bg(:primary_light)
      "bg-prime-cyan-100"
  """
  def bg(:primary), do: "bg-prime-cyan-400"
  def bg(:primary_light), do: "bg-prime-cyan-100"
  def bg(:primary_dark), do: "bg-prime-cyan-600"
  def bg(:secondary), do: "bg-prime-magenta-400"
  def bg(:secondary_light), do: "bg-prime-magenta-100"
  def bg(:secondary_dark), do: "bg-prime-magenta-600"
  def bg(:accent), do: "bg-prime-yellow-400"
  def bg(:accent_light), do: "bg-prime-yellow-100"
  def bg(:surface), do: "bg-white"
  def bg(:muted), do: "bg-gray-50"
  def bg(:light), do: "bg-gray-100"
  def bg(:medium), do: "bg-gray-200"

  # ============================================
  # TEXT COLOR CLASSES
  # ============================================

  @doc """
  Returns the text color class for the specified variant.

  ## Variants

  - `:primary`, `:primary_dark` - Cyan text
  - `:secondary`, `:secondary_dark` - Magenta text
  - `:accent` - Yellow text
  - `:heading` - Dark gray for headings
  - `:body` - Medium gray for body text
  - `:muted` - Light gray for secondary text
  - `:inverse` - White text for dark backgrounds

  ## Examples

      iex> Theme.text_color(:primary)
      "text-prime-cyan-400"

      iex> Theme.text_color(:heading)
      "text-gray-900"
  """
  def text_color(:primary), do: "text-prime-cyan-400"
  def text_color(:primary_dark), do: "text-prime-cyan-600"
  def text_color(:secondary), do: "text-gray-600"
  def text_color(:secondary_dark), do: "text-prime-magenta-600"
  def text_color(:accent), do: "text-prime-yellow-400"
  def text_color(:accent_dark), do: "text-prime-yellow-600"
  def text_color(:heading), do: "text-gray-900"
  def text_color(:body), do: "text-gray-700"
  def text_color(:muted), do: "text-gray-500"
  def text_color(:subtle), do: "text-gray-400"
  def text_color(:inverse), do: "text-white"

  # ============================================
  # BORDER COLOR CLASSES
  # ============================================

  @doc """
  Returns the border color class for the specified variant.

  ## Examples

      iex> Theme.border_color(:primary)
      "border-prime-cyan-400"

      iex> Theme.border_color(:light)
      "border-gray-200"
  """
  def border_color(:primary), do: "border-prime-cyan-400"
  def border_color(:primary_light), do: "border-prime-cyan-200"
  def border_color(:secondary), do: "border-prime-magenta-400"
  def border_color(:accent), do: "border-prime-yellow-400"
  def border_color(:light), do: "border-gray-200"
  def border_color(:medium), do: "border-gray-300"
  def border_color(:dark), do: "border-gray-400"

  # ============================================
  # ICON STYLE PAIRS (bg + text)
  # ============================================

  @doc """
  Returns a tuple of {background_class, text_class} for icon styling.

  ## Variants

  - `:primary`, `:secondary`, `:accent` - Brand colors
  - `:success`, `:warning`, `:danger`, `:info` - Status colors

  ## Examples

      {bg, text} = Theme.icon_styles(:primary)
      # bg = "bg-prime-cyan-100"
      # text = "text-prime-cyan-400"
  """
  def icon_styles(:primary), do: {"bg-prime-cyan-100", "text-prime-cyan-400"}
  def icon_styles(:secondary), do: {"bg-prime-magenta-100", "text-prime-magenta-400"}
  def icon_styles(:accent), do: {"bg-prime-yellow-100", "text-prime-yellow-600"}
  def icon_styles(:success), do: {"bg-green-100", "text-green-600"}
  def icon_styles(:warning), do: {"bg-yellow-100", "text-yellow-600"}
  def icon_styles(:danger), do: {"bg-red-100", "text-red-600"}
  def icon_styles(:info), do: {"bg-blue-100", "text-blue-600"}
  def icon_styles(:neutral), do: {"bg-gray-100", "text-gray-600"}

  # ============================================
  # STATUS CLASSES (for badges, pills, info boxes)
  # ============================================

  @doc """
  Returns combined classes for status indicators (badges, pills, info boxes).

  Includes background, border, and text color in one string.

  ## Variants

  - `:available` - Green (positive/success state)
  - `:limited` - Yellow (warning state)
  - `:full` - Red (negative/danger state)
  - `:info` - Blue (informational)
  - `:neutral` - Gray (default/inactive)

  ## Examples

      iex> Theme.status(:available)
      "bg-green-50 border-green-200 text-green-700"
  """
  def status(:available), do: "bg-green-50 border-green-200 text-green-700"
  def status(:limited), do: "bg-yellow-50 border-yellow-200 text-yellow-700"
  def status(:full), do: "bg-red-50 border-red-200 text-red-700"
  def status(:info), do: "bg-blue-50 border-blue-200 text-blue-700"
  def status(:neutral), do: "bg-gray-50 border-gray-200 text-gray-700"

  # ============================================
  # ICON SIZES
  # ============================================

  @doc """
  Returns width and height classes for icon sizing.

  ## Sizes

  - `:xs` - 12px (w-3 h-3)
  - `:sm` - 16px (w-4 h-4)
  - `:md` - 20px (w-5 h-5) - Default
  - `:lg` - 24px (w-6 h-6)
  - `:xl` - 32px (w-8 h-8)
  - `:"2xl"` - 40px (w-10 h-10)

  ## Examples

      iex> Theme.icon_size(:md)
      "w-5 h-5"
  """
  def icon_size(:xs), do: "w-3 h-3"
  def icon_size(:sm), do: "w-4 h-4"
  def icon_size(:md), do: "w-5 h-5"
  def icon_size(:lg), do: "w-6 h-6"
  def icon_size(:xl), do: "w-8 h-8"
  def icon_size(:"2xl"), do: "w-10 h-10"

  # ============================================
  # SPACING SCALE
  # ============================================

  @doc """
  Returns the Tailwind spacing value (number only) for the specified size.

  Use with padding, margin, or gap classes: `p-{spacing(:md)}` → `p-4`

  ## Scale

  - `:xs` - 1 (4px)
  - `:sm` - 2 (8px)
  - `:md` - 4 (16px)
  - `:lg` - 6 (24px)
  - `:xl` - 8 (32px)
  - `:"2xl"` - 12 (48px)

  ## Examples

      iex> Theme.spacing(:md)
      "4"
  """
  def spacing(:xs), do: "1"
  def spacing(:sm), do: "2"
  def spacing(:md), do: "4"
  def spacing(:lg), do: "6"
  def spacing(:xl), do: "8"
  def spacing(:"2xl"), do: "12"

  # ============================================
  # SHADOW SCALE
  # ============================================

  @doc """
  Returns the shadow class for the specified level.

  ## Levels

  - `:none` - No shadow
  - `:sm` - Subtle shadow
  - `:md` - Medium shadow
  - `:lg` - Large shadow
  - `:xl` - Extra large shadow

  ## Examples

      iex> Theme.shadow(:md)
      "shadow-md"
  """
  def shadow(:none), do: "shadow-none"
  def shadow(:sm), do: "shadow-sm"
  def shadow(:md), do: "shadow-md"
  def shadow(:lg), do: "shadow-lg"
  def shadow(:xl), do: "shadow-xl"

  # ============================================
  # TYPOGRAPHY SCALE
  # ============================================

  @doc """
  Returns typography classes for the specified style.

  Includes font size, weight, and responsive variants.

  ## Styles

  - `:hero` - Page hero text (largest)
  - `:page_title` - Main page titles
  - `:section_title` - Section headings
  - `:card_title` - Card/component headings
  - `:body` - Default body text
  - `:body_small` - Smaller body text
  - `:caption` - Small muted text

  ## Examples

      iex> Theme.typography(:hero)
      "text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight"
  """
  def typography(:hero), do: "text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight"
  def typography(:page_title), do: "text-3xl md:text-4xl font-bold"
  def typography(:section_title), do: "text-2xl md:text-3xl font-bold"
  def typography(:card_title), do: "text-lg font-semibold"
  def typography(:body), do: "text-base"
  def typography(:body_small), do: "text-sm"
  def typography(:caption), do: "text-xs text-gray-500"

  # ============================================
  # BORDER RADIUS
  # ============================================

  @doc """
  Returns the border radius class for the specified size.

  ## Sizes

  - `:none` - No rounding
  - `:sm` - Small rounding (4px)
  - `:md` - Medium rounding (8px)
  - `:lg` - Large rounding (12px)
  - `:xl` - Extra large (16px)
  - `:full` - Fully rounded (pill shape)

  ## Examples

      iex> Theme.rounded(:lg)
      "rounded-xl"
  """
  def rounded(:none), do: "rounded-none"
  def rounded(:sm), do: "rounded"
  def rounded(:md), do: "rounded-lg"
  def rounded(:lg), do: "rounded-xl"
  def rounded(:xl), do: "rounded-2xl"
  def rounded(:full), do: "rounded-full"

  # ============================================
  # TRANSITIONS
  # ============================================

  @doc """
  Returns transition classes for the specified speed.

  ## Speeds

  - `:fast` - 150ms
  - `:normal` - 200ms (default)
  - `:slow` - 300ms

  ## Examples

      iex> Theme.transition(:normal)
      "transition-all duration-200"
  """
  def transition(:fast), do: "transition-all duration-150"
  def transition(:normal), do: "transition-all duration-200"
  def transition(:slow), do: "transition-all duration-300"

  # ============================================
  # COMPONENT VARIANT HELPERS
  # ============================================

  @doc """
  Returns combined classes for a button variant.

  ## Variants

  - `:primary` - Primary CTA button
  - `:secondary` - Secondary action button
  - `:outline` - Bordered outline button
  - `:ghost` - Minimal/text button

  ## Examples

      iex> Theme.button_variant(:primary)
      "bg-prime-cyan-400 text-white hover:bg-prime-cyan-500"
  """
  def button_variant(:primary), do: "bg-prime-cyan-400 text-white hover:bg-prime-cyan-500"
  def button_variant(:secondary), do: "bg-prime-magenta-400 text-white hover:bg-prime-magenta-500"
  def button_variant(:outline), do: "border-2 border-gray-200 text-gray-700 hover:bg-gray-50"
  def button_variant(:ghost), do: "text-gray-600 hover:bg-gray-100"

  @doc """
  Returns combined classes for a card variant.

  ## Variants

  - `:default` - Standard card with subtle shadow
  - `:elevated` - Card with larger shadow
  - `:outlined` - Card with border, no shadow
  - `:glass` - Glassmorphism effect

  ## Examples

      iex> Theme.card_variant(:default)
      "bg-white rounded-xl shadow-sm border border-gray-100"
  """
  def card_variant(:default), do: "bg-white rounded-xl shadow-sm border border-gray-100"
  def card_variant(:elevated), do: "bg-white rounded-xl shadow-lg"
  def card_variant(:outlined), do: "bg-white rounded-xl border-2 border-gray-200"
  def card_variant(:glass), do: "bg-white/80 backdrop-blur-sm rounded-xl shadow-sm"
end

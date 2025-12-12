defmodule PrimeYouthWeb.Theme do
  @moduledoc """
  Centralized theme utilities for Prime Youth design system.

  This module provides consistent access to gradients, colors, spacing, shadows,
  typography, and other design tokens used throughout the Prime Youth application.

  ## Design Tokens

  - **Colors**: Primary (teal), Secondary (pink), Accent (yellow)
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
    primary: "bg-gradient-to-r from-teal-500 to-teal-600",
    hero: "bg-gradient-to-br from-teal-400 via-teal-500 to-teal-600",
    safety: "bg-gradient-to-r from-green-500 to-emerald-600"
  }

  @doc """
  Returns the gradient class for the specified gradient name.

  ## Available Gradients

  - `:primary` - Teal horizontal gradient (teal-500 to teal-600)
  - `:hero` - Teal diagonal gradient (teal-400 via teal-500 to teal-600)
  - `:safety` - Green horizontal gradient (green-500 to emerald-600)

  ## Examples

      iex> Theme.gradient(:primary)
      "bg-gradient-to-r from-teal-500 to-teal-600"

      iex> Theme.gradient(:hero)
      "bg-gradient-to-br from-teal-400 via-teal-500 to-teal-600"

      iex> Theme.gradient(:safety)
      "bg-gradient-to-r from-green-500 to-emerald-600"
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
    primary: "teal",
    secondary: "pink",
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
  # BRAND COLORS
  # ============================================

  @brand_colors %{
    # Primary brand color (teal)
    primary: "teal-600",
    primary_hover: "teal-700",
    primary_light: "teal-50",

    # Accent color (pink)
    accent: "pink-500",
    accent_hover: "pink-600",

    # Surface colors
    surface: "white",
    surface_light: "slate-50",

    # Text colors
    text_primary: "slate-900",
    text_secondary: "slate-700",
    text_muted: "slate-500",

    # Border colors
    border_light: "slate-200",
    border_medium: "slate-300",

    # Footer
    footer_bg: "slate-900",
    footer_text: "slate-300"
  }

  @doc """
  Returns the brand color value for the given key.

  This map provides centralized brand color management for easy rebranding.
  All color values are Tailwind color names that can be used directly in classes.

  ## Available Colors

  ### Primary Colors
  - `:primary` - Main brand color (teal-600)
  - `:primary_hover` - Hover state (teal-700)
  - `:primary_light` - Light background (teal-50)

  ### Accent Colors
  - `:accent` - Accent highlights (pink-500)
  - `:accent_hover` - Accent hover (pink-600)

  ### Surface Colors
  - `:surface` - Default background (white)
  - `:surface_light` - Light surface (slate-50)

  ### Text Colors
  - `:text_primary` - Primary text (slate-900)
  - `:text_secondary` - Secondary text (slate-700)
  - `:text_muted` - Muted text (slate-500)

  ### Border Colors
  - `:border_light` - Subtle borders (slate-200)
  - `:border_medium` - Medium borders (slate-300)

  ### Footer Colors
  - `:footer_bg` - Footer background (slate-900)
  - `:footer_text` - Footer text (slate-300)

  ## Examples

      iex> Theme.brand_color(:primary)
      "teal-600"

      iex> Theme.brand_color(:accent)
      "pink-500"

      iex> Theme.brand_color(:text_primary)
      "slate-900"
  """
  def brand_color(key), do: Map.get(@brand_colors, key)

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
  def bg(:primary), do: "bg-teal-600"
  def bg(:primary_light), do: "bg-teal-50"
  def bg(:primary_dark), do: "bg-teal-700"
  def bg(:secondary), do: "bg-pink-500"
  def bg(:secondary_light), do: "bg-pink-50"
  def bg(:secondary_dark), do: "bg-pink-700"
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
  def text_color(:primary), do: "text-teal-600"
  def text_color(:primary_dark), do: "text-teal-700"
  def text_color(:secondary), do: "text-gray-600"
  def text_color(:secondary_dark), do: "text-pink-600"
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
  def border_color(:primary), do: "border-teal-500"
  def border_color(:primary_light), do: "border-teal-200"
  def border_color(:secondary), do: "border-pink-500"
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
  def icon_styles(:primary), do: {"bg-teal-50", "text-teal-600"}
  def icon_styles(:secondary), do: {"bg-pink-50", "text-pink-500"}
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
  def button_variant(:primary), do: "bg-teal-600 text-white hover:bg-teal-700"
  def button_variant(:secondary), do: "bg-pink-500 text-white hover:bg-pink-600"
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

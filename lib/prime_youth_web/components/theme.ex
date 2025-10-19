defmodule PrimeYouthWeb.Theme do
  @moduledoc """
  Centralized theme utilities for Prime Youth design system.

  This module provides consistent access to gradients, colors, and other
  design tokens used throughout the Prime Youth application.

  ## Usage

      # In components:
      import PrimeYouthWeb.Theme

      <div class={gradient(:primary)}>...</div>
      <div class={gradient(:warm)}>...</div>

      # Or with full module name:
      <div class={Theme.gradient(:hero)}>...</div>
  """

  @gradients %{
    # Primary brand gradients
    primary: "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400",
    hero: "bg-gradient-to-br from-prime-cyan-400 via-prime-magenta-400 to-prime-yellow-400",

    # Warm gradients (yellows, oranges, reds)
    warm: "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600",
    warm_intense: "bg-gradient-to-br from-orange-400 via-pink-500 to-purple-600",

    # Cool gradients (blues, cyans, purples)
    cool: "bg-gradient-to-br from-prime-cyan-400 to-blue-500",
    cool_magenta: "bg-gradient-to-br from-prime-magenta-400 to-pink-500",
    cool_purple: "bg-gradient-to-br from-pink-400 via-purple-500 to-indigo-600",

    # Nature gradients (greens)
    nature: "bg-gradient-to-br from-green-400 via-blue-500 to-purple-600",
    success: "bg-gradient-to-br from-green-500 via-emerald-600 to-teal-700",

    # Neutral/Dark gradients
    dark: "bg-gradient-to-br from-gray-700 via-gray-800 to-black",
    tech: "bg-gradient-to-br from-blue-500 via-indigo-600 to-purple-700",

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

  ## Examples

      iex> Theme.gradient(:primary)
      "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"

      iex> Theme.gradient(:warm)
      "bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600"

      iex> Theme.gradient(:unknown)
      "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400"
  """
  def gradient(name) when is_atom(name) do
    Map.get(@gradients, name, @gradients.primary)
  end

  @doc """
  Returns all available gradient names.

  ## Examples

      iex> Theme.available_gradients()
      [:primary, :hero, :warm, :cool, ...]
  """
  def available_gradients do
    Map.keys(@gradients)
  end

  @doc """
  Returns a map of all gradients.

  Useful for debugging or generating documentation.
  """
  def all_gradients do
    @gradients
  end
end

defmodule PrimeYouthWeb.LayoutComponents do
  @moduledoc """
  Layout and structural components for Prime Youth application.

  This module contains components for page structure, headers,
  and other layout-related functionality.
  """
  use Phoenix.Component
  use Gettext, backend: PrimeYouthWeb.Gettext

  @doc """
  Renders a section header with title, optional description, and icon.

  ## Examples

      <.section_header title="What We Offer" />

      <.section_header
        title="Featured Programs"
        description="Discover our most popular activities for children"
        icon="hero-star" />

      <.section_header
        title="Ready to Get Started?"
        description="Join hundreds of families who trust Prime Youth"
        centered={true}
        class="mb-8" />
  """
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :icon, :string, default: nil
  attr :centered, :boolean, default: false
  attr :class, :string, default: ""

  def section_header(assigns) do
    ~H"""
    <div class={[
      if(@centered, do: "text-center", else: ""),
      @class
    ]}>
      <h2 class={[
        "text-4xl font-bold text-base-content mb-4",
        if(@centered, do: "mx-auto", else: "")
      ]}>
        <span :if={@icon} class="inline-flex items-center">
          <.icon name={@icon} class="w-8 h-8 mr-3 text-primary" />
        </span>
        {@title}
      </h2>
      <p :if={@description} class={[
        "text-lg text-base-content/70",
        if(@centered, do: "max-w-2xl mx-auto", else: "max-w-3xl")
      ]}>
        {@description}
      </p>
    </div>
    """
  end

  @doc """
  Renders a page header with title, optional subtitle, and action slot.

  ## Examples

      <.page_header title="Programs" />

      <.page_header title="Dashboard" subtitle="Welcome back, Sarah!" />

      <.page_header title="Program Details" subtitle="Chess Masters">
        <:actions>
          <button class="btn btn-primary">Enroll Now</button>
          <button class="btn btn-outline">Add to Favorites</button>
        </:actions>
      </.page_header>
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :class, :string, default: ""

  slot :actions, doc: "Action buttons or controls"

  def page_header(assigns) do
    ~H"""
    <div class={[
      "bg-base-100 border-b border-base-200 px-6 py-8",
      @class
    ]}>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-base-content">{@title}</h1>
          <p :if={@subtitle} class="text-lg text-base-content/70 mt-1">
            {@subtitle}
          </p>
        </div>
        <div :if={@actions != []} class="flex items-center gap-3">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an icon.

  Icons are provided by [heroicons](https://heroicons.com). Each icon can be
  used in "outline" or "solid" style (outline is the default).

  You can find the full list of icons at [heroicons](https://heroicons.com).

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
defmodule PrimeYouthWeb.UIComponents do
  @moduledoc """
  Reusable UI components for Prime Youth application.

  This module contains general-purpose UI components that can be used
  across multiple pages and contexts.
  """
  use Phoenix.Component
  use Gettext, backend: PrimeYouthWeb.Gettext

  @doc """
  Renders a search input with icon and Prime Youth styling.

  ## Examples

      <.search_bar placeholder="Search programs..." value={@search_term} />

      <.search_bar
        placeholder="Search..."
        value={@query}
        name="search"
        class="mb-4" />
  """
  attr :placeholder, :string, default: "Search..."
  attr :value, :string, default: ""
  attr :name, :string, default: "search"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-change phx-submit phx-debounce disabled readonly)

  def search_bar(assigns) do
    ~H"""
    <div class={["relative", @class]}>
      <input
        type="text"
        name={@name}
        placeholder={@placeholder}
        value={@value}
        class="input input-bordered w-full pl-10 pr-4 bg-base-100 border-base-300 focus:border-primary focus:ring-primary"
        {@rest}
      />
      <svg
        class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-base-content/40"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        />
      </svg>
    </div>
    """
  end

  @doc """
  Renders horizontally scrollable filter pills.

  ## Examples

      <.filter_pills
        filters={[
          %{id: "all", label: "All Programs", active: true},
          %{id: "available", label: "Available", active: false},
          %{id: "ages", label: "By Age", active: false}
        ]}
        on_select="filter_change" />

      <.filter_pills
        filters={@filter_options}
        active_filter={@current_filter}
        class="mb-4" />
  """
  attr :filters, :list,
    required: true,
    doc: "List of filter maps with :id, :label, and optionally :active"

  attr :active_filter, :string, default: nil, doc: "ID of the currently active filter"

  attr :on_select, :string,
    default: "filter_select",
    doc: "Phoenix event name to send when filter is selected"

  attr :class, :string, default: ""

  def filter_pills(assigns) do
    ~H"""
    <div class={["flex gap-2 overflow-x-auto pb-2", @class]}>
      <div class="flex gap-2 min-w-max">
        <button
          :for={filter <- @filters}
          phx-click={@on_select}
          phx-value-filter={filter.id}
          class={[
            "btn btn-sm",
            if(is_active?(filter, @active_filter), do: "btn-primary", else: "btn-ghost")
          ]}
        >
          {filter.label}
        </button>
      </div>
    </div>
    """
  end

  # Helper function to determine if a filter is active
  defp is_active?(filter, active_filter) when is_binary(active_filter) do
    filter.id == active_filter
  end

  defp is_active?(filter, _) do
    Map.get(filter, :active, false)
  end

  @doc """
  Renders a status badge with color coding based on variant.

  ## Examples

      <.status_badge variant="success">5 spots left</.status_badge>

      <.status_badge variant="warning">2 spots left</.status_badge>

      <.status_badge variant="error">Full</.status_badge>

      <.status_badge variant="info" class="mb-2">Available</.status_badge>
  """
  attr :variant, :string, default: "info", values: ~w(success warning error info)
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def status_badge(assigns) do
    ~H"""
    <span
      class={[
        "badge",
        variant_class(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  # Helper function to get badge classes based on variant
  defp variant_class("success"), do: "badge-success"
  defp variant_class("warning"), do: "badge-warning"
  defp variant_class("error"), do: "badge-error"
  defp variant_class("info"), do: "badge-info"
  defp variant_class(_), do: "badge-info"

  @doc """
  Renders a statistics card with icon, value, and description.

  ## Examples

      <.stat_card
        icon="hero-users"
        title="Happy Families"
        value="500+"
        description="Families trust us with their children"
        color="primary" />

      <.stat_card
        icon="hero-academic-cap"
        title="Programs"
        value="25+"
        description="Different activity programs"
        color="secondary" />
  """
  attr :icon, :string, required: true, doc: "Heroicon name"
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :description, :string, required: true
  attr :color, :string, default: "primary", values: ~w(primary secondary accent)
  attr :class, :string, default: ""

  def stat_card(assigns) do
    ~H"""
    <div class={["stat", @class]}>
      <div class={["stat-figure", stat_color(@color)]}>
        <.icon name={@icon} class="w-8 h-8" />
      </div>
      <div class="stat-title">{@title}</div>
      <div class={["stat-value", stat_color(@color)]}>{@value}</div>
      <div class="stat-desc">{@description}</div>
    </div>
    """
  end

  # Helper function to get color classes for stats
  defp stat_color("primary"), do: "text-primary"
  defp stat_color("secondary"), do: "text-secondary"
  defp stat_color("accent"), do: "text-accent"
  defp stat_color(_), do: "text-primary"

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

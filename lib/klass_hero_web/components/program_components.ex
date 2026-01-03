defmodule KlassHeroWeb.ProgramComponents do
  @moduledoc """
  Provides program-specific components for Klass Hero application.

  This module contains domain-specific components related to programs,
  activities, and the program catalog.
  """
  use Phoenix.Component

  import KlassHeroWeb.UIComponents

  alias KlassHeroWeb.Theme

  @doc """
  Renders a search input with icon and Klass Hero styling.

  ## Examples

      <.search_bar
        placeholder="Search programs..."
        value={@search_term}
        phx-change="search"
      />
  """
  attr :placeholder, :string, default: "Search programs..."
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
        class={[
          "w-full px-4 py-3 pl-11 border border-hero-grey-300 focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:border-transparent",
          Theme.transition(:normal),
          Theme.rounded(:lg)
        ]}
        {@rest}
      />
      <.icon
        name="hero-magnifying-glass"
        class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-hero-grey-400"
      />
    </div>
    """
  end

  @doc """
  Renders horizontally scrollable filter pills.

  ## Examples

      <.filter_pills
        filters={[
          %{id: "all", label: "All Programs"},
          %{id: "available", label: "Available"},
          %{id: "ages", label: "By Age"}
        ]}
        active_filter={@current_filter}
        phx-click="filter_select"
      />
  """
  attr :filters, :list,
    required: true,
    doc: "List of filter maps with :id and :label"

  attr :active_filter, :string, required: true, doc: "ID of the currently active filter"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def filter_pills(assigns) do
    ~H"""
    <div class={["flex gap-2 overflow-x-auto pb-2 scrollbar-hide", @class]}>
      <div class="flex gap-2 min-w-max">
        <button
          :for={filter <- @filters}
          data-filter-id={filter.id}
          data-active={if filter.id == @active_filter, do: "true", else: "false"}
          phx-click={@rest[:"phx-click"]}
          phx-value-filter={filter.id}
          class={[
            "px-4 py-2 text-sm font-medium whitespace-nowrap",
            Theme.transition(:normal),
            Theme.rounded(:full),
            if(filter.id == @active_filter,
              do: "bg-hero-blue-600 text-white shadow-md",
              else:
                "bg-white text-hero-black-100 border border-hero-grey-300 hover:border-hero-grey-400"
            )
          ]}
        >
          {filter.label}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a program card with gradient header, favorite button, and program details.

  Supports two variants:
  - `:detailed` - Full card with all program information (for programs page)
  - `:compact` - Simplified card for homepage or listings

  ## Examples

      <.program_card
        program={@program}
        variant={:detailed}
        phx-click="program_click"
        phx-value-program={@program.title}
      />
  """
  attr :program, :map, required: true
  attr :variant, :atom, default: :detailed, values: [:compact, :detailed]
  attr :show_favorite, :boolean, default: true
  attr :favorited, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def program_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-white shadow-sm border border-hero-grey-100",
        Theme.rounded(:xl),
        "hover:shadow-lg hover:scale-[1.02]",
        Theme.transition(:slow),
        "overflow-hidden cursor-pointer",
        @class
      ]}
      {@rest}
    >
      <!-- Program Image/Header -->
      <div class={["h-48 relative overflow-hidden", @program.gradient_class]}>
        <div class="absolute inset-0 bg-black/10"></div>
        
    <!-- Favorite Button -->
        <div :if={@show_favorite} class="absolute top-4 right-4 z-10">
          <button
            phx-click="toggle_favorite"
            phx-value-program={@program.title}
            class={[
              "p-2 bg-white shadow-sm hover:bg-hero-grey-50",
              Theme.transition(:normal),
              Theme.rounded(:full)
            ]}
            onclick="event.stopPropagation();"
          >
            <svg
              class={[
                "w-5 h-5",
                Theme.transition(:normal),
                if(@favorited,
                  do: "text-red-500 fill-red-500",
                  else: "text-hero-black-100 hover:text-red-500"
                )
              ]}
              fill={if @favorited, do: "currentColor", else: "none"}
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
              />
            </svg>
          </button>
        </div>
        
    <!-- Spots Left Badge -->
        <.spots_badge :if={@program.spots_left <= 5} spots_left={@program.spots_left} />
        
    <!-- Program Icon -->
        <div class="absolute inset-0 flex items-center justify-center">
          <div class={[
            "w-16 h-16 bg-white/20 backdrop-blur-sm flex items-center justify-center",
            Theme.rounded(:full)
          ]}>
            <svg
              class="w-8 h-8 text-white"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d={@program.icon_path}
              />
            </svg>
          </div>
        </div>
      </div>
      
    <!-- Program Info -->
      <div class="p-6">
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <h3 class={[Theme.typography(:card_title), "text-hero-black mb-2"]}>{@program.title}</h3>
            <p class="text-hero-black-100 text-sm mb-3 line-clamp-2">{@program.description}</p>
          </div>
        </div>
        
    <!-- Program Details -->
        <div class="space-y-2 mb-4">
          <div class="flex items-center text-sm text-hero-black-100">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            {@program.schedule}
          </div>
          <div class="flex items-center text-sm text-hero-grey-500">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
              />
            </svg>
            Ages {@program.age_range}
          </div>
        </div>
        
    <!-- Price -->
        <div class="pt-4 border-t border-hero-grey-100">
          <div class={[Theme.typography(:card_title), Theme.text_color(:primary)]}>
            {format_price(@program.price)}
          </div>
          <div class="text-sm text-hero-grey-500">{@program.period}</div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a "spots left" badge.

  Shows warning colors based on remaining spots:
  - Red when 2 or fewer spots
  - Orange when 3-5 spots

  ## Examples

      <.spots_badge spots_left={3} />
  """
  attr :spots_left, :integer, required: true
  attr :class, :string, default: ""

  def spots_badge(assigns) do
    ~H"""
    <div class={["absolute bottom-4 left-4", @class]}>
      <span class={[
        "px-2 py-1 text-xs font-medium",
        Theme.rounded(:full),
        if(@spots_left <= 2,
          do: "bg-red-100 text-red-700",
          else: "bg-orange-100 text-orange-700"
        )
      ]}>
        {@spots_left} spots left!
      </span>
    </div>
    """
  end

  # Helper function to format price
  defp format_price(price) when is_integer(price) or is_float(price) do
    "€#{:erlang.float_to_binary(price / 1, decimals: 2)}"
  end

  defp format_price(price) when is_binary(price), do: price

  @doc """
  Renders a formatted price with currency and period.

  ## Examples

      <.price_display price={45} period="week" />
      <.price_display price={30} period="session" />
      <.price_display price={120} currency="USD" period="month" />
  """
  attr :price, :integer, required: true
  attr :currency, :string, default: "€", doc: "Currency symbol"

  attr :period, :string,
    default: "week",
    values: ~w(week session month hour),
    doc: "Billing period"

  attr :class, :string, default: ""

  def price_display(assigns) do
    ~H"""
    <div class={["text-right", @class]}>
      <div class={[Theme.typography(:section_title), Theme.text_color(:primary)]}>
        {@currency}{@price}
      </div>
      <div class="text-xs text-hero-grey-400">
        per {@period}
      </div>
    </div>
    """
  end
end

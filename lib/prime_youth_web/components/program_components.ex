defmodule PrimeYouthWeb.ProgramComponents do
  @moduledoc """
  Provides program-specific components for Prime Youth application.

  This module contains domain-specific components related to programs,
  activities, and the program catalog.
  """
  use Phoenix.Component
  import PrimeYouthWeb.UIComponents

  @doc """
  Renders a search input with icon and Prime Youth styling.

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
        class="w-full px-4 py-3 pl-11 border border-gray-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-prime-cyan-400 focus:border-transparent transition-all"
        {@rest}
      />
      <.icon
        name="hero-magnifying-glass"
        class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400"
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
          phx-click={@rest[:"phx-click"]}
          phx-value-filter={filter.id}
          class={[
            "px-4 py-2 rounded-full text-sm font-medium transition-all whitespace-nowrap",
            if(filter.id == @active_filter,
              do: "bg-gradient-to-r from-prime-cyan-400 to-prime-magenta-400 text-white shadow-md",
              else: "bg-white text-gray-700 border border-gray-300 hover:border-gray-400"
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
  Renders a program card with all details.

  ## Examples

      <.program_card
        id="1"
        title="Creative Art World"
        description="Unleash your child's creativity"
        gradient_class="bg-gradient-to-br from-yellow-400 via-orange-500 to-yellow-600"
        icon_emoji="🎨"
        price={45}
        ages="6-12"
        duration="8 weeks"
        schedule="Wednesdays 4-6 PM"
        spots_left={3}
        category="Arts & Crafts"
      />
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :gradient_class, :string, required: true
  attr :icon_emoji, :string, required: true
  attr :price, :integer, required: true
  attr :ages, :string, required: true
  attr :duration, :string, required: true
  attr :schedule, :string, required: true
  attr :spots_left, :integer, required: true
  attr :category, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-value-*)

  def program_card(assigns) do
    ~H"""
    <div
      class={[
        "bg-white rounded-2xl shadow-md overflow-hidden",
        "hover:shadow-xl transition-all duration-300 hover:scale-[1.02]",
        "cursor-pointer",
        @class
      ]}
      {@rest}
    >
      <!-- Gradient Header with Icon -->
      <div class={[
        "relative h-32 flex items-center justify-center text-white overflow-hidden",
        @gradient_class
      ]}>
        <div class="text-6xl">{@icon_emoji}</div>
        <.status_pill
          color="custom"
          class={"absolute top-3 right-3 #{spots_badge_color(@spots_left)}"}
        >
          {spots_badge_text(@spots_left)}
        </.status_pill>
      </div>

      <!-- Card Content -->
      <div class="p-6">
        <!-- Title and Description -->
        <h3 class="text-xl font-bold text-gray-900 mb-2">{@title}</h3>
        <p class="text-gray-600 text-sm mb-4 line-clamp-2">{@description}</p>

        <!-- Details Grid -->
        <div class="grid grid-cols-2 gap-3 mb-4 text-sm">
          <div class="flex items-center gap-2 text-gray-700">
            <.icon name="hero-user-group" class="w-4 h-4 text-gray-400" />
            <span>{@ages} years</span>
          </div>
          <div class="flex items-center gap-2 text-gray-700">
            <.icon name="hero-clock" class="w-4 h-4 text-gray-400" />
            <span>{@duration}</span>
          </div>
          <div class="flex items-center gap-2 text-gray-700 col-span-2">
            <.icon name="hero-calendar" class="w-4 h-4 text-gray-400" />
            <span>{@schedule}</span>
          </div>
        </div>

        <!-- Footer with Category and Price -->
        <div class="flex items-center justify-between pt-4 border-t border-gray-200">
          <.status_pill color="custom" class="bg-gray-100 text-gray-700">
            {@category}
          </.status_pill>
          <.price_display price={@price} period="week" />
        </div>
      </div>
    </div>
    """
  end

  defp spots_badge_color(spots) when spots <= 2, do: "bg-red-100 text-red-700"
  defp spots_badge_color(spots) when spots <= 5, do: "bg-orange-100 text-orange-700"
  defp spots_badge_color(_), do: "bg-green-100 text-green-700"

  defp spots_badge_text(0), do: "Full"
  defp spots_badge_text(1), do: "1 spot left"
  defp spots_badge_text(spots), do: "#{spots} spots left"

  @doc """
  Renders a formatted price with currency and period.

  ## Examples

      <.price_display price={45} period="week" />
      <.price_display price={30} period="session" />
      <.price_display price={120} currency="USD" period="month" />
  """
  attr :price, :integer, required: true
  attr :currency, :string, default: "€", doc: "Currency symbol"
  attr :period, :string, default: "week", values: ~w(week session month hour), doc: "Billing period"
  attr :class, :string, default: ""

  def price_display(assigns) do
    ~H"""
    <div class={["text-right", @class]}>
      <div class="text-2xl font-bold text-prime-cyan-400">
        {@currency}{@price}
      </div>
      <div class="text-xs text-gray-500">
        per {@period}
      </div>
    </div>
    """
  end
end

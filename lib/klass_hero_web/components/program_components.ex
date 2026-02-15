defmodule KlassHeroWeb.ProgramComponents do
  @moduledoc """
  Provides program-specific components for Klass Hero application.

  This module contains domain-specific components related to programs,
  activities, and the program catalog.
  """
  use Phoenix.Component

  import KlassHeroWeb.UIComponents

  alias KlassHero.ProgramCatalog
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
  Renders horizontally scrollable trending tag pills.

  ## Examples

      <.trending_tags
        tags={["Swimming", "Math Tutor", "Summer Camp", "Piano", "Soccer"]}
      />
  """
  attr :tags, :list, required: true, doc: "List of trending tag strings"
  attr :class, :string, default: ""

  def trending_tags(assigns) do
    ~H"""
    <div class={["flex gap-2 overflow-x-auto pb-2 scrollbar-hide mt-4", @class]}>
      <div class="flex gap-2 min-w-max">
        <span
          :for={tag <- @tags}
          class={[
            "px-3 py-1.5 text-sm font-medium whitespace-nowrap",
            "bg-white/20 backdrop-blur-sm text-white border border-white/30",
            "hover:bg-white/30",
            Theme.transition(:normal),
            Theme.rounded(:full)
          ]}
        >
          {tag}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a sort dropdown button (visual only, no functionality).

  ## Examples

      <.sort_dropdown selected={@sort_by} />
  """
  attr :selected, :string, default: "Recommended", doc: "Currently selected sort option"
  attr :class, :string, default: ""

  def sort_dropdown(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "px-4 py-2 bg-white border border-hero-grey-300 text-hero-black-100",
        "hover:border-hero-grey-400 flex items-center gap-2",
        Theme.transition(:normal),
        Theme.rounded(:lg),
        @class
      ]}
    >
      <span class="text-sm font-medium">{@selected}</span>
      <.icon name="hero-chevron-down" class="w-4 h-4" />
    </button>
    """
  end

  @doc """
  Renders view toggle buttons (Grid/List).

  ## Examples

      <.view_toggle active_view={:grid} />
  """
  attr :active_view, :atom, default: :grid, values: [:grid, :list]
  attr :class, :string, default: ""

  def view_toggle(assigns) do
    ~H"""
    <div class={["flex gap-1 bg-hero-grey-100 p-1", Theme.rounded(:lg), @class]}>
      <button
        type="button"
        class={[
          "p-2",
          Theme.transition(:normal),
          Theme.rounded(:md),
          if(@active_view == :grid,
            do: "bg-white text-hero-blue-600 shadow-sm",
            else: "text-hero-grey-500 hover:text-hero-grey-700"
          )
        ]}
      >
        <.icon name="hero-squares-2x2" class="w-5 h-5" />
      </button>
      <button
        type="button"
        disabled
        class={[
          "p-2 opacity-40 cursor-not-allowed",
          Theme.transition(:normal),
          Theme.rounded(:md),
          if(@active_view == :list,
            do: "bg-white text-hero-blue-600 shadow-sm",
            else: "text-hero-grey-500"
          )
        ]}
      >
        <.icon name="hero-bars-3" class="w-5 h-5" />
      </button>
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
        
    <!-- Category Badge (top-left) -->
        <div :if={Map.get(@program, :category)} class="absolute top-4 left-4 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-white/90 text-hero-black backdrop-blur-sm",
            Theme.rounded(:full)
          ]}>
            {@program.category}
          </span>
        </div>
        
    <!-- ONLINE Badge -->
        <div :if={Map.get(@program, :is_online, false)} class="absolute top-4 left-4 mt-10 z-10">
          <span class={[
            "px-3 py-1 text-xs font-semibold bg-hero-blue-500 text-white",
            Theme.rounded(:full)
          ]}>
            ONLINE
          </span>
        </div>
        
    <!-- Favorite Button (top-right) -->
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
        
    <!-- Spots Left Badge (bottom-left) -->
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
        
    <!-- Provider Info -->
        <div
          :if={Map.get(@program, :provider_name)}
          class="flex items-center gap-2 mb-4 pb-3 border-b border-hero-grey-100"
        >
          <div class={[
            "w-8 h-8 bg-hero-blue-100 text-hero-blue-600 flex items-center justify-center text-xs font-semibold",
            Theme.rounded(:full)
          ]}>
            {Map.get(@program, :provider_avatar, "KH")}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-1">
              <span class="text-sm font-medium text-hero-black truncate">
                {@program.provider_name}
              </span>
              <svg
                :if={Map.get(@program, :is_verified, false)}
                class="w-4 h-4 text-hero-blue-500 flex-shrink-0"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div
              :if={Map.get(@program, :provider_location)}
              class="text-xs text-hero-grey-500 truncate"
            >
              {@program.provider_location}
            </div>
          </div>
        </div>
        
    <!-- Rating -->
        <div :if={Map.get(@program, :rating)} class="flex items-center gap-2 mb-4">
          <div class="flex items-center">
            <%= for _i <- 1..5 do %>
              <svg class="w-4 h-4 text-yellow-400 fill-current" viewBox="0 0 20 20">
                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
              </svg>
            <% end %>
          </div>
          <span class="text-sm font-medium text-hero-black">{@program.rating}</span>
          <span
            :if={Map.get(@program, :review_count)}
            class="text-sm text-hero-grey-500"
          >
            ({@program.review_count} reviews)
          </span>
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
            {format_schedule_brief(@program)}
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
            {ProgramCatalog.format_price(@program.price)}
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

  # Schedule Formatting Helpers
  # These work with raw maps (sample fixtures) rather than domain structs.

  @day_abbreviations %{
    "Monday" => "Mon",
    "Tuesday" => "Tue",
    "Wednesday" => "Wed",
    "Thursday" => "Thu",
    "Friday" => "Fri",
    "Saturday" => "Sat",
    "Sunday" => "Sun"
  }

  defp format_schedule_brief(program) do
    days = Map.get(program, :meeting_days, [])
    start_time = Map.get(program, :meeting_start_time)
    end_time = Map.get(program, :meeting_end_time)

    day_str = if days != [], do: format_day_list(days)
    time_str = format_time_range(start_time, end_time)

    [day_str, time_str]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp format_day_list([day]), do: Map.get(@day_abbreviations, day, day)

  defp format_day_list(days) when is_list(days) do
    Enum.map_join(days, ", ", &Map.get(@day_abbreviations, &1, &1))
  end

  defp format_time_range(%Time{} = start_time, %Time{} = end_time) do
    # Trigger: both times in the same AM/PM period
    # Why: "4:00 - 5:30 PM" reads cleaner than "4:00 PM - 5:30 PM"
    # Outcome: omit period from start time when both share the same period
    same_period? = start_time.hour >= 12 == end_time.hour >= 12

    if same_period? do
      "#{format_time_12h(start_time, false)} - #{format_time_12h(end_time, true)}"
    else
      "#{format_time_12h(start_time, true)} - #{format_time_12h(end_time, true)}"
    end
  end

  defp format_time_range(_, _), do: nil

  defp format_time_12h(%Time{hour: hour, minute: minute}, show_period) do
    {h12, period} = if hour >= 12, do: {rem(hour, 12), "PM"}, else: {hour, "AM"}
    h12 = if h12 == 0, do: 12, else: h12
    minutes_str = String.pad_leading("#{minute}", 2, "0")

    if show_period do
      "#{h12}:#{minutes_str} #{period}"
    else
      "#{h12}:#{minutes_str}"
    end
  end
end

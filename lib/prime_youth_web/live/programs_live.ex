defmodule PrimeYouthWeb.ProgramsLive do
  use PrimeYouthWeb, :live_view

  import PrimeYouthWeb.ProgramComponents

  alias PrimeYouth.ProgramCatalog.Application.UseCases.FilterPrograms
  alias PrimeYouth.ProgramCatalog.Application.UseCases.ListAllPrograms
  alias PrimeYouthWeb.ErrorIds
  alias PrimeYouthWeb.Theme

  require Logger

  @valid_filters ["all", "available", "ages", "price"]

  # Private helpers - Static data
  defp filter_options do
    [
      %{id: "all", label: "All Programs"},
      %{id: "available", label: "Available"},
      %{id: "ages", label: "By Age"},
      %{id: "price", label: "By Price"}
    ]
  end

  @impl true
  def mount(_params, _session, socket) do
    # Initialize socket state - actual program loading happens in handle_params
    socket =
      socket
      |> assign(page_title: "Programs")
      |> assign(current_user: nil)
      |> assign(search_query: "")
      |> assign(active_filter: "all")
      |> stream(:programs, [])
      |> assign(programs_count: 0)
      |> assign(programs_empty?: true)
      |> assign(filters: filter_options())
      |> assign(database_error: false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    search_query = sanitize_search_query(params["q"])
    active_filter = validate_filter(params["filter"])

    # Re-fetch and filter programs based on params
    case ListAllPrograms.execute() do
      {:ok, domain_programs} ->
        start_time = System.monotonic_time(:millisecond)
        # Apply search filter to domain programs BEFORE converting to maps
        filtered_domain = FilterPrograms.execute(domain_programs, search_query)
        # Convert to maps for UI
        programs = Enum.map(filtered_domain, &program_to_map/1)
        # Apply category filter
        filtered = filter_by_category(programs, active_filter)
        duration_ms = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "[ProgramsLive.handle_params] Filter operation completed",
          search_query: search_query,
          result_count: length(filtered),
          duration_ms: duration_ms,
          current_user_id: get_user_id(socket)
        )

        if duration_ms > 150 do
          Logger.warning(
            "[ProgramsLive.handle_params] Filter operation exceeded performance target",
            search_query: search_query,
            result_count: length(filtered),
            duration_ms: duration_ms,
            target_ms: 150,
            current_user_id: get_user_id(socket)
          )
        end

        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, filtered, reset: true)
          |> assign(:programs_empty?, Enum.empty?(filtered))
          |> assign(database_error: false)

        {:noreply, socket}

      {:error, :database_connection_error} ->
        Logger.error(
          "[ProgramsLive.handle_params] Database connection error",
          error_id: ErrorIds.program_list_connection_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, [], reset: true)
          |> assign(:programs_empty?, true)
          |> assign(database_error: true)
          |> put_flash(:error, "Connection lost. Please try again.")

        {:noreply, socket}

      {:error, :database_query_error} ->
        Logger.error(
          "[ProgramsLive.handle_params] Database query error",
          error_id: ErrorIds.program_list_query_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, [], reset: true)
          |> assign(:programs_empty?, true)
          |> assign(:database_error, true)
          |> put_flash(:error, "System error. Please contact support.")

        {:noreply, socket}

      {:error, :database_unavailable} ->
        Logger.error(
          "[ProgramsLive.handle_params] Database unavailable",
          error_id: ErrorIds.program_list_generic_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        socket =
          socket
          |> assign(search_query: search_query)
          |> assign(active_filter: active_filter)
          |> stream(:programs, [], reset: true)
          |> assign(:programs_empty?, true)
          |> assign(:database_error, true)
          |> put_flash(:error, "Service temporarily unavailable.")

        {:noreply, socket}
    end
  end

  # Private helper - Domain to UI conversion
  defp program_to_map(%PrimeYouth.ProgramCatalog.Domain.Models.Program{} = program) do
    %{
      id: program.id,
      title: program.title,
      description: program.description,
      schedule: program.schedule,
      age_range: program.age_range,
      price: safe_decimal_to_float(program.price),
      period: program.pricing_period,
      spots_left: program.spots_available,
      # Default UI properties (these will come from the database in the future)
      gradient_class: program.gradient_class || default_gradient_class(),
      icon_path: program.icon_path || default_icon_path()
    }
  end

  defp default_gradient_class, do: Theme.gradient(:program_default)

  defp default_icon_path,
    do: "M12 14l9-5-9-5-9 5 9 5zm0 7l-9-5 9-5 9 5-9 5zM3 12l9-5 9 5-9 5-9-5z"

  # Safe conversion helper to prevent crashes on invalid Decimal values
  defp safe_decimal_to_float(price) do
    Decimal.to_float(price)
  rescue
    _ -> 0.0
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    params = build_query_params(socket.assigns, q: query)
    {:noreply, push_patch(socket, to: ~p"/programs?#{params}")}
  end

  @impl true
  def handle_event("filter_select", %{"filter" => filter_id}, socket) do
    params = build_query_params(socket.assigns, filter: filter_id)
    {:noreply, push_patch(socket, to: ~p"/programs?#{params}")}
  end

  @impl true
  def handle_event("toggle_favorite", %{"program" => _program_title}, socket) do
    # TODO: Implement favorite toggle functionality
    {:noreply, socket}
  end

  @impl true
  def handle_event("program_click", %{"program" => program_title}, socket) do
    # Find program by title from database and navigate to detail page
    case ListAllPrograms.execute() do
      {:ok, domain_programs} ->
        programs = Enum.map(domain_programs, &program_to_map/1)

        case Enum.find(programs, fn p -> p.title == program_title end) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Program not found. Please try refreshing the page.")
             |> push_patch(to: ~p"/programs")}

          program ->
            {:noreply, push_navigate(socket, to: ~p"/programs/#{program.id}")}
        end

      {:error, :database_connection_error} ->
        Logger.error(
          "[ProgramsLive.program_click] Database connection error",
          error_id: ErrorIds.program_list_connection_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        {:noreply,
         socket
         |> put_flash(:error, "Connection lost. Please try again.")
         |> push_patch(to: ~p"/programs")}

      {:error, :database_query_error} ->
        Logger.error(
          "[ProgramsLive.program_click] Database query error",
          error_id: ErrorIds.program_list_query_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        {:noreply,
         socket
         |> put_flash(:error, "System error. Please contact support.")
         |> push_patch(to: ~p"/programs")}

      {:error, :database_unavailable} ->
        Logger.error(
          "[ProgramsLive.program_click] Database unavailable",
          error_id: ErrorIds.program_list_generic_error(),
          current_user_id: get_user_id(socket),
          live_view: __MODULE__
        )

        {:noreply,
         socket
         |> put_flash(:error, "Service temporarily unavailable.")
         |> push_patch(to: ~p"/programs")}
    end
  end

  # Private helpers - URL and parameter handling
  defp build_query_params(assigns, updates) do
    # Convert keyword list updates to string-keyed map
    updates_map =
      updates
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    %{
      "q" => assigns.search_query,
      "filter" => assigns.active_filter
    }
    |> Map.merge(updates_map)
    |> Enum.reject(fn {_k, v} -> v == "" || v == "all" end)
    |> Map.new()
  end

  defp validate_filter(nil), do: "all"
  defp validate_filter(filter) when filter in @valid_filters, do: filter
  defp validate_filter(_invalid), do: "all"

  defp sanitize_search_query(nil), do: ""

  defp sanitize_search_query(query) do
    query
    |> String.trim()
    |> String.slice(0, 100)
  end

  # Private helpers - Business logic
  defp filter_by_category(programs, "all"), do: programs

  defp filter_by_category(programs, "available") do
    Enum.filter(programs, &(&1.spots_left > 0))
  end

  defp filter_by_category(programs, "ages") do
    # Sort by age range (youngest first)
    Enum.sort_by(programs, &extract_min_age(&1.age_range))
  end

  defp filter_by_category(programs, "price") do
    # Sort by price (lowest first)
    Enum.sort_by(programs, & &1.price)
  end

  # Safe age extraction with fallback for unparseable formats
  # Returns 999 for unparseable age ranges to sort them to the end
  defp extract_min_age(age_range) do
    with [first | _] <- String.split(age_range, "-"),
         trimmed = String.trim(first),
         {age, _} <- Integer.parse(trimmed) do
      age
    else
      _ -> 999
    end
  end

  # Extract user ID from socket for logging context
  # Returns nil if user is not authenticated
  defp get_user_id(socket) do
    case socket.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pb-20 md:pb-6">
      <!-- Header -->
      <.page_header>
        <:title>Programs</:title>
        <:actions>
          <.icon_button
            icon_path="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
            variant="light"
            class="text-gray-600"
            aria_label="More options"
          />
        </:actions>
      </.page_header>

      <div class="p-6">
        <!-- Search Bar -->
        <.search_bar
          id="search-programs"
          placeholder="Search programs..."
          value={@search_query}
          name="search"
          phx-change="search"
          phx-hook="Debounce"
          data-debounce="150"
          class="mb-4"
        />
        
    <!-- Filter Pills -->
        <.filter_pills
          filters={@filters}
          active_filter={@active_filter}
          phx-click="filter_select"
        />
        
    <!-- Programs List -->
        <div
          id="programs"
          phx-update="stream"
          class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          <.program_card
            :for={{dom_id, program} <- @streams.programs}
            id={dom_id}
            program={program}
            variant={:detailed}
            phx-click="program_click"
            phx-value-program={program.title}
          />
        </div>
        
    <!-- Empty State -->
        <.empty_state
          :if={@programs_empty?}
          icon_path="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          title="No programs found"
          description="Try adjusting your search or filter criteria."
        />
      </div>
    </div>
    """
  end
end

defmodule KlassHeroWeb.Staff.StaffDashboardLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.Enrollment
  alias KlassHero.ProgramCatalog
  alias KlassHero.Provider
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member

    case Provider.get_provider_profile(staff_member.provider_id) do
      {:ok, provider} ->
        all_programs = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)
        programs = Provider.list_assigned_programs(staff_member, all_programs)
        assigned_ids = MapSet.new(programs, & &1.id)

        socket =
          socket
          |> assign(:page_title, gettext("Staff Dashboard"))
          |> assign(:provider, provider)
          |> assign(:staff_member, staff_member)
          |> assign(:assigned_program_ids, assigned_ids)
          |> assign(:programs_empty?, programs == [])
          |> assign(:show_roster, false)
          |> assign(:roster_entries, [])
          |> assign(:roster_program_name, nil)
          |> assign(:roster_program_id, nil)
          |> stream(:programs, programs)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           gettext("The business associated with your account could not be found.")
         )
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("view_roster", %{"id" => program_id} = params, socket) do
    if MapSet.member?(socket.assigns.assigned_program_ids, program_id) do
      roster = Enrollment.list_program_enrollments(program_id)

      {:noreply,
       assign(socket,
         show_roster: true,
         roster_program_name: Map.get(params, "title", program_id),
         roster_program_id: program_id,
         roster_entries: roster
       )}
    else
      {:noreply, put_flash(socket, :error, gettext("Unauthorized"))}
    end
  end

  @impl true
  def handle_event("close_roster", _params, socket) do
    {:noreply,
     assign(socket,
       show_roster: false,
       roster_entries: [],
       roster_program_name: nil,
       roster_program_id: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="staff-dashboard" class="max-w-4xl mx-auto px-4 py-6">
      <div id="business-name" class="mb-6">
        <h1 class={Theme.typography(:page_title)}>
          {@provider.business_name}
        </h1>
        <p class={Theme.typography(:body)}>
          {gettext("Welcome, %{name}", name: @staff_member.first_name)}
        </p>
      </div>

      <div class="mt-8">
        <h2 class={Theme.typography(:section_title)}>
          {gettext("Assigned Programs")}
        </h2>

        <div :if={@programs_empty?} id="programs-empty-state" class="text-center py-8 text-zinc-500">
          {gettext("No programs assigned yet.")}
        </div>

        <div id="assigned-programs" phx-update="stream" class="mt-4 space-y-4">
          <div
            :for={{dom_id, program} <- @streams.programs}
            id={dom_id}
            class="p-4 bg-white rounded-lg shadow-sm border border-zinc-200"
          >
            <h3 class={Theme.typography(:card_title)}>{program.title}</h3>
            <p :if={program.category} class="text-sm text-zinc-500 mt-1">{program.category}</p>

            <div class="flex gap-2 mt-3">
              <.link
                id={"sessions-link-#{program.id}"}
                navigate={~p"/staff/sessions?program_id=#{program.id}"}
                class={[
                  "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium",
                  "text-hero-blue-600 bg-hero-blue-50 hover:bg-hero-blue-100",
                  "rounded-md transition-colors"
                ]}
              >
                <.icon name="hero-calendar-days-mini" class="w-4 h-4" />
                {gettext("Sessions")}
              </.link>

              <button
                id={"roster-btn-#{program.id}"}
                phx-click="view_roster"
                phx-value-id={program.id}
                phx-value-title={program.title}
                class={[
                  "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium",
                  "text-hero-grey-700 bg-hero-grey-100 hover:bg-hero-grey-200",
                  "rounded-md transition-colors"
                ]}
              >
                <.icon name="hero-user-group-mini" class="w-4 h-4" />
                {gettext("Roster")}
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Staff Roster Modal --%>
      <%= if @show_roster do %>
        <div
          id="staff-roster-backdrop"
          class="fixed inset-0 z-50 bg-black/50"
          phx-click="close_roster"
        >
        </div>
        <div
          id="staff-roster-modal"
          class={[
            "fixed inset-x-4 top-[10%] z-50 mx-auto max-w-lg bg-white",
            "rounded-xl shadow-xl max-h-[80vh] overflow-y-auto"
          ]}
        >
          <div class="flex items-center justify-between p-4 border-b border-hero-grey-200">
            <h2 class="text-lg font-semibold text-hero-charcoal">
              {gettext("Roster: %{name}", name: @roster_program_name)}
            </h2>
            <button
              id="close-roster-btn"
              phx-click="close_roster"
              class="p-1 text-hero-grey-400 hover:text-hero-grey-600"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div class="p-4">
            <%= if @roster_entries == [] do %>
              <p class="text-center text-hero-grey-500 py-4">
                {gettext("No enrollments yet.")}
              </p>
            <% else %>
              <ul class="divide-y divide-hero-grey-200">
                <%= for entry <- @roster_entries do %>
                  <li class="py-3 flex items-center justify-between">
                    <div>
                      <span class="font-medium text-hero-charcoal">
                        {Map.get(entry, :child_name, gettext("Unknown"))}
                      </span>
                    </div>
                    <span class="text-sm text-hero-grey-500">
                      {Map.get(entry, :status, "")}
                    </span>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

defmodule KlassHeroWeb.Staff.StaffDashboardLive do
  use KlassHeroWeb, :live_view

  alias KlassHero.ProgramCatalog
  alias KlassHero.Provider
  alias KlassHeroWeb.Theme

  @impl true
  def mount(_params, _session, socket) do
    staff_member = socket.assigns.current_scope.staff_member
    {:ok, provider} = Provider.get_provider_profile(staff_member.provider_id)

    all_programs = ProgramCatalog.list_programs_for_provider(staff_member.provider_id)

    programs =
      if staff_member.tags == [] do
        all_programs
      else
        Enum.filter(all_programs, fn p -> p.category in staff_member.tags end)
      end

    socket =
      socket
      |> assign(:page_title, gettext("Staff Dashboard"))
      |> assign(:provider, provider)
      |> assign(:staff_member, staff_member)
      |> assign(:programs_empty?, programs == [])
      |> stream(:programs, programs)

    {:ok, socket}
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
          </div>
        </div>
      </div>
    </div>
    """
  end
end

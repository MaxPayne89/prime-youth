defmodule PrimeYouthWeb.ProviderLive.Dashboard do
  @moduledoc """
  LiveView for provider program management dashboard.

  Displays all programs created by the current provider, grouped by approval status:
  - Draft: Programs being edited, not yet submitted
  - Pending Approval: Programs submitted for admin review
  - Approved: Programs visible in the marketplace
  - Rejected: Programs rejected by admin, awaiting changes

  Providers can create new programs, edit existing programs, and view their
  submission status in real-time.
  """

  use PrimeYouthWeb, :live_view

  import Ecto.Query

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program
  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Provider
  alias PrimeYouth.Repo

  @impl true
  def mount(_params, _session, socket) do
    # Get current user from scope
    current_user = socket.assigns.current_scope.user

    # Get provider for current user
    provider = get_provider_by_user_id(current_user.id)

    if provider do
      # Subscribe to real-time notifications for this provider
      Phoenix.PubSub.subscribe(
        PrimeYouth.PubSub,
        "provider:#{provider.id}:notifications"
      )

      # Get all programs for this provider
      programs = list_provider_programs(provider.id)

      # Group programs by status
      grouped_programs = group_programs_by_status(programs)

      socket =
        socket
        |> assign(:page_title, "My Programs")
        |> assign(:provider, provider)
        |> assign(:programs, programs)
        |> assign(:draft_programs, grouped_programs.draft)
        |> assign(:pending_programs, grouped_programs.pending_approval)
        |> assign(:approved_programs, grouped_programs.approved)
        |> assign(:rejected_programs, grouped_programs.rejected)
        |> assign(:active_tab, "draft")

      {:ok, socket}
    else
      # No provider found for this user - need to create provider profile
      socket =
        socket
        |> put_flash(:error, "Please complete your provider profile first.")
        |> redirect(to: ~p"/dashboard")

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    active_tab = Map.get(params, "tab", "draft")

    socket = assign(socket, :active_tab, active_tab)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/provider/dashboard?tab=#{tab}")}
  end

  @impl true
  def handle_event("delete_program", %{"id" => program_id}, socket) do
    program = Repo.get!(Program, program_id)

    # Only allow deleting draft programs
    if program.status == "draft" and program.provider_id == socket.assigns.provider.id do
      case Repo.delete(program) do
        {:ok, _deleted_program} ->
          # Refresh program list
          programs = list_provider_programs(socket.assigns.provider.id)
          grouped_programs = group_programs_by_status(programs)

          socket =
            socket
            |> put_flash(:info, "Program deleted successfully.")
            |> assign(:programs, programs)
            |> assign(:draft_programs, grouped_programs.draft)
            |> assign(:pending_programs, grouped_programs.pending_approval)
            |> assign(:approved_programs, grouped_programs.approved)
            |> assign(:rejected_programs, grouped_programs.rejected)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete program.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only draft programs can be deleted.")}
    end
  end

  @impl true
  def handle_event("submit_for_approval", %{"id" => program_id}, socket) do
    program = Repo.get!(Program, program_id)

    # Only allow submitting draft programs
    if program.status == "draft" and program.provider_id == socket.assigns.provider.id do
      changeset = Ecto.Changeset.change(program, status: "pending_approval")

      case Repo.update(changeset) do
        {:ok, _updated_program} ->
          # Refresh program list
          programs = list_provider_programs(socket.assigns.provider.id)
          grouped_programs = group_programs_by_status(programs)

          socket =
            socket
            |> put_flash(:info, "Program submitted for approval successfully.")
            |> assign(:programs, programs)
            |> assign(:draft_programs, grouped_programs.draft)
            |> assign(:pending_programs, grouped_programs.pending_approval)
            |> assign(:approved_programs, grouped_programs.approved)
            |> assign(:rejected_programs, grouped_programs.rejected)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to submit program.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only draft programs can be submitted.")}
    end
  end

  # Handle real-time PubSub notifications
  @impl true
  def handle_info({:program_approved, %{program_id: _program_id}}, socket) do
    # Refresh program list when a program is approved
    programs = list_provider_programs(socket.assigns.provider.id)
    grouped_programs = group_programs_by_status(programs)

    socket =
      socket
      |> put_flash(:info, "Your program has been approved!")
      |> assign(:programs, programs)
      |> assign(:draft_programs, grouped_programs.draft)
      |> assign(:pending_programs, grouped_programs.pending_approval)
      |> assign(:approved_programs, grouped_programs.approved)
      |> assign(:rejected_programs, grouped_programs.rejected)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:program_rejected, %{program_id: _program_id, reason: reason}}, socket) do
    # Refresh program list when a program is rejected
    programs = list_provider_programs(socket.assigns.provider.id)
    grouped_programs = group_programs_by_status(programs)

    socket =
      socket
      |> put_flash(:error, "Your program was rejected: #{reason}")
      |> assign(:programs, programs)
      |> assign(:draft_programs, grouped_programs.draft)
      |> assign(:pending_programs, grouped_programs.pending_approval)
      |> assign(:approved_programs, grouped_programs.approved)
      |> assign(:rejected_programs, grouped_programs.rejected)

    {:noreply, socket}
  end

  # Private helper functions

  defp get_provider_by_user_id(user_id) do
    Repo.one(from p in Provider, where: p.user_id == ^user_id)
  end

  defp list_provider_programs(provider_id) do
    Program
    |> where([p], p.provider_id == ^provider_id)
    |> where([p], is_nil(p.archived_at))
    |> order_by([p], desc: p.inserted_at)
    |> preload([:schedules, :locations])
    |> Repo.all()
  end

  defp group_programs_by_status(programs) do
    programs
    |> Enum.group_by(& &1.status)
    |> Map.merge(
      %{
        "draft" => [],
        "pending_approval" => [],
        "approved" => [],
        "rejected" => []
      },
      fn _k, v1, v2 -> v1 || v2 end
    )
    |> Map.new(fn {status, progs} ->
      {String.to_atom(status), progs}
    end)
  end

  defp format_status(status) do
    case status do
      "draft" -> "Draft"
      "pending_approval" -> "Pending"
      "approved" -> "Approved"
      "rejected" -> "Rejected"
      _ -> String.capitalize(status)
    end
  end

  # Function component for rendering program lists
  attr :programs, :list, required: true
  attr :status, :string, required: true
  attr :empty_title, :string, required: true
  attr :empty_description, :string, required: true

  defp render_program_list(assigns) do
    ~H"""
    <%= if @programs == [] do %>
      <div class="text-center py-12">
        <svg
          class="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">{@empty_title}</h3>
        <p class="mt-1 text-sm text-gray-500">{@empty_description}</p>
        <%= if @status == "draft" do %>
          <.link
            navigate={~p"/provider/programs/new"}
            class="mt-4 inline-flex items-center px-4 py-2 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
          >
            Create Program
          </.link>
        <% end %>
      </div>
    <% else %>
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for program <- @programs do %>
          <div
            id={"program-#{program.id}"}
            class="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow"
          >
            <%!-- Program Image Placeholder --%>
            <div class="aspect-video bg-gray-200 relative">
              <span class={[
                "absolute top-2 right-2 px-2 py-1 text-xs font-semibold rounded-full",
                case @status do
                  "draft" -> "bg-gray-600 text-white"
                  "pending_approval" -> "bg-yellow-600 text-white"
                  "approved" -> "bg-green-600 text-white"
                  "rejected" -> "bg-red-600 text-white"
                  _ -> "bg-gray-600 text-white"
                end
              ]}>
                {format_status(@status)}
              </span>
            </div>

            <%!-- Program Details --%>
            <div class="p-4">
              <h3 class="text-lg font-semibold text-gray-900 line-clamp-2">
                {program.title}
              </h3>

              <p class="mt-2 text-sm text-gray-600 line-clamp-2">
                {program.description}
              </p>

              <div class="mt-4 flex items-center justify-between text-sm">
                <div class="flex items-center gap-2">
                  <span class="text-xs font-medium text-gray-500 uppercase">
                    {program.category}
                  </span>
                  <span class="text-xs text-gray-400">
                    Ages {program.age_min}-{program.age_max}
                  </span>
                </div>

                <div class="text-right">
                  <%= if program.price_amount && Decimal.compare(program.price_amount, 0) == :gt do %>
                    <p class="font-semibold text-gray-900">
                      ${Decimal.to_string(program.price_amount)}
                    </p>
                  <% else %>
                    <p class="font-semibold text-green-600">
                      Free
                    </p>
                  <% end %>
                </div>
              </div>

              <%!-- Rejection Reason (only for rejected programs) --%>
              <%= if @status == "rejected" && program.rejection_reason do %>
                <div class="mt-3 p-3 bg-red-50 border border-red-200 rounded-md">
                  <p class="text-sm font-medium text-red-800">Rejection Reason:</p>
                  <p class="mt-1 text-sm text-red-700">{program.rejection_reason}</p>
                </div>
              <% end %>

              <%!-- Action Buttons --%>
              <div class="mt-4 flex flex-col sm:flex-row gap-2">
                <%= if @status == "draft" do %>
                  <.link
                    id={"edit-program-#{program.id}"}
                    navigate={~p"/provider/programs/#{program.id}/edit"}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Edit
                  </.link>
                  <button
                    id={"submit-program-#{program.id}"}
                    phx-click="submit_for_approval"
                    phx-value-id={program.id}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Submit
                  </button>
                  <button
                    phx-click="delete_program"
                    phx-value-id={program.id}
                    data-confirm="Are you sure you want to delete this program?"
                    class="inline-flex items-center justify-center px-3 py-2 border border-red-300 shadow-sm text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                  >
                    Delete
                  </button>
                <% end %>

                <%= if @status == "pending_approval" do %>
                  <.link
                    navigate={~p"/provider/programs/#{program.id}"}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    View
                  </.link>
                <% end %>

                <%= if @status == "approved" do %>
                  <.link
                    navigate={~p"/programs/#{program.id}"}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    View Listing
                  </.link>
                  <.link
                    navigate={~p"/provider/programs/#{program.id}/edit"}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-indigo-600 shadow-sm text-sm font-medium rounded-md text-indigo-700 bg-white hover:bg-indigo-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Edit
                  </.link>
                <% end %>

                <%= if @status == "rejected" do %>
                  <.link
                    navigate={~p"/provider/programs/#{program.id}/edit"}
                    class="flex-1 inline-flex items-center justify-center px-3 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Edit & Resubmit
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end
end

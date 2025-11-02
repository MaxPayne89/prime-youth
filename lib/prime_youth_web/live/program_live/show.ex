defmodule PrimeYouthWeb.ProgramLive.Show do
  @moduledoc """
  LiveView for displaying detailed information about a single program.

  Shows comprehensive program information including description, schedules,
  locations, pricing, and enrollment details.
  """

  use PrimeYouthWeb, :live_view

  alias PrimeYouth.ProgramCatalog.UseCases.BrowsePrograms

  @impl true
  def mount(%{"id" => program_id}, _session, socket) do
    case BrowsePrograms.get_program(program_id) do
      {:ok, program} ->
        socket =
          socket
          |> assign(:program, program)
          |> assign(:page_title, program.title)

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Program not found")
          |> redirect(to: ~p"/programs")

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("enroll", _params, socket) do
    # TODO: Implement enrollment flow in User Story 2
    # For now, just show a message
    socket =
      socket
      |> put_flash(:info, "Enrollment flow coming soon!")

    {:noreply, socket}
  end

  # Private helpers

  defp format_schedule(schedule) do
    days = Enum.join(schedule.days_of_week, ", ")
    start_time = Calendar.strftime(schedule.start_time, "%I:%M %p")
    end_time = Calendar.strftime(schedule.end_time, "%I:%M %p")

    "#{days}, #{start_time} - #{end_time}"
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d, %Y")
  end

  defp format_location(location) do
    if location.is_virtual do
      "Virtual"
    else
      "#{location.address_line1}, #{location.city}, #{location.state} #{location.postal_code}"
    end
  end
end

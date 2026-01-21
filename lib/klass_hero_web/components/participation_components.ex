defmodule KlassHeroWeb.ParticipationComponents do
  @moduledoc """
  Provides participation-specific components for Klass Hero application.

  This module contains domain-specific components for participation check-in/out workflows,
  session management, and participation status tracking for providers and parents.
  """
  use Phoenix.Component

  import KlassHeroWeb.CoreComponents, only: [input: 1]
  import KlassHeroWeb.UIComponents

  alias KlassHero.Participation.Domain.Services.ParticipationCollection
  alias KlassHeroWeb.Theme

  @doc """
  Renders a session participation card with check-in status information.

  Displays session details including program name, date, time, location, and current
  check-in status. Supports customizable action buttons via the `:actions` slot.

  ## Examples

      <.participation_card session={@session} role={:provider}>
        <:actions>
          <button phx-click="start_session" class="btn-primary">
            Start Session
          </button>
        </:actions>
      </.participation_card>

      <.participation_card session={@session} role={:parent} />
  """
  attr :session, :map, required: true, doc: "Session map with participation details"

  attr :role, :atom,
    required: true,
    values: [:provider, :parent],
    doc: "User role viewing the card"

  attr :class, :string, default: "", doc: "Additional CSS classes"
  slot :actions, doc: "Action buttons for the session"

  def participation_card(assigns) do
    ~H"""
    <div class={[
      "bg-white border border-hero-grey-200 p-4 md:p-6",
      Theme.rounded(:lg),
      Theme.shadow(:md),
      @class
    ]}>
      <%!-- Session header --%>
      <div class="flex items-start justify-between gap-4 mb-4">
        <div class="flex-1">
          <h3 class="text-lg font-semibold text-hero-black">
            {Map.get(@session, :program_name, "Session")}
          </h3>
          <p class="text-sm text-hero-black-100 mt-1">
            {format_session_datetime(@session)}
          </p>
        </div>
        <.participation_status status={@session.status} />
      </div>

      <%!-- Session details --%>
      <div class="space-y-2 mb-4">
        <div class="flex items-center gap-2 text-sm text-hero-black-100">
          <.icon name="hero-map-pin" class="w-4 h-4 text-hero-grey-400" />
          <span>{Map.get(@session, :location, "Location TBD")}</span>
        </div>

        <%= if @role == :provider && Map.get(@session, :capacity) do %>
          <div class="flex items-center gap-2 text-sm text-hero-black-100">
            <.icon name="hero-user-group" class="w-4 h-4 text-hero-grey-400" />
            <span>
              {Map.get(@session, :checked_in_count, 0)} / {Map.get(@session, :capacity)} checked in
            </span>
          </div>
        <% end %>
      </div>

      <%!-- Actions slot --%>
      <%= if @actions != [] do %>
        <div class="flex gap-2 flex-wrap">
          {render_slot(@actions)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a status badge for sessions and participation records.

  Displays color-coded status indicators with icons for various states including
  session statuses (scheduled, in_progress, completed) and participation statuses
  (checked_in, checked_out, absent).

  ## Examples

      <.participation_status status={:scheduled} />
      <.participation_status status={:checked_in} size={:lg} />
      <.participation_status status={:absent} />
  """
  attr :status, :atom,
    required: true,
    values: [:scheduled, :in_progress, :completed, :checked_in, :checked_out, :absent],
    doc: "Status to display"

  attr :size, :atom, default: :md, values: [:sm, :md, :lg], doc: "Badge size"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def participation_status(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 font-medium whitespace-nowrap",
      size_classes(@size),
      status_color_classes(@status),
      Theme.rounded(:full),
      @class
    ]}>
      <.icon name={status_icon(@status)} class={icon_size_classes(@size)} />
      <span>{status_label(@status)}</span>
    </span>
    """
  end

  @doc """
  Renders a batch check-in form with roster and notes.

  Provides an interactive form for providers to check in multiple children at once
  with optional notes. Displays the session roster with child names and status.

  ## Examples

      <.check_in_form
        form={@form}
        participation_records={@participation_records}
        session={@session}
        on_submit="submit_participation"
      />
  """
  attr :form, Phoenix.HTML.Form, required: true, doc: "Form struct from to_form/2"

  attr :participation_records, :list,
    required: true,
    doc:
      "List of enriched participation record maps with child_first_name and child_last_name fields"

  attr :session, :map, required: true, doc: "Session map"
  attr :on_submit, :string, required: true, doc: "Phoenix event for form submission"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def check_in_form(assigns) do
    ~H"""
    <div class={[
      "bg-white border border-hero-grey-200 p-4 md:p-6",
      Theme.rounded(:lg),
      Theme.shadow(:md),
      @class
    ]}>
      <.form for={@form} id="participation-form" phx-submit={@on_submit}>
        <%!-- Session context --%>
        <div class="mb-6">
          <h3 class="text-lg font-semibold text-hero-black mb-2">
            Participation Check-In
          </h3>
          <p class="text-sm text-hero-grey-600">
            {format_session_datetime(@session)}
          </p>
        </div>

        <%!-- Roster grid --%>
        <div class="space-y-3 mb-6">
          <h4 class="text-sm font-medium text-hero-black-100">Session Roster</h4>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div
              :for={record <- @participation_records}
              class={[
                "border p-3",
                Theme.rounded(:md),
                if(record.status == :checked_in,
                  do: "border-green-300 bg-green-50",
                  else: "border-hero-grey-200 bg-white"
                )
              ]}
            >
              <label class="flex items-start gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  name="participation[checked_in][]"
                  value={record.id}
                  checked={record.status == :checked_in}
                  class="mt-1 w-4 h-4 text-hero-blue-600 rounded border-hero-grey-300 focus:ring-hero-blue-500"
                />
                <div class="flex-1">
                  <div class="font-medium text-hero-black">
                    {record.child_first_name} {record.child_last_name}
                  </div>
                  <%= if record.status == :checked_in && record.check_in_at do %>
                    <div class="text-xs text-hero-grey-500 mt-1">
                      Checked in at {format_time(record.check_in_at)}
                    </div>
                  <% end %>
                </div>
                <.participation_status status={record.status} size={:sm} />
              </label>
            </div>
          </div>
        </div>

        <%!-- Notes field --%>
        <div class="mb-6">
          <.input
            field={@form[:notes]}
            type="textarea"
            label="Session Notes (optional)"
            placeholder="Any important notes about today's session..."
            rows="3"
          />
        </div>

        <%!-- Submit button --%>
        <div class="flex gap-3">
          <button
            type="submit"
            class={[
              "flex-1 px-4 py-3 bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700 focus:outline-none focus:ring-2 focus:ring-teal-500 focus:ring-offset-2",
              Theme.rounded(:lg),
              Theme.transition(:normal)
            ]}
          >
            Submit Participation
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders a session roster list with participation status.

  Displays all children enrolled in a session with their current participation status.
  Supports an editable mode with action buttons per record via the `:actions` slot.

  ## Examples

      <.roster_list
        participation_records={@participation_records}
        session={@session}
        editable={true}
      >
        <:actions :let={record}>
          <%= if record.status == :checked_in do %>
            <button phx-click="check_out" phx-value-id={record.id} class="btn-sm">
              Check Out
            </button>
          <% else %>
            <button phx-click="check_in" phx-value-id={record.id} class="btn-sm">
              Check In
            </button>
          <% end %>
        </:actions>
      </.roster_list>
  """
  attr :participation_records, :list,
    required: true,
    doc:
      "List of enriched participation record maps with child_first_name and child_last_name fields"

  attr :session, :map, required: true, doc: "Session map"
  attr :editable, :boolean, default: false, doc: "Whether to show action buttons"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  attr :checkout_form_expanded, :string,
    default: nil,
    doc: "Record ID with checkout form expanded"

  attr :checkout_forms, :map,
    default: %{},
    doc: "Map of record_id => form structs"

  slot :actions, doc: "Action buttons per record" do
    attr :record, :map
  end

  def roster_list(assigns) do
    ~H"""
    <div class={[
      "bg-white border border-hero-grey-200",
      Theme.rounded(:lg),
      Theme.shadow(:md),
      @class
    ]}>
      <%!-- Header with count --%>
      <div class="p-4 md:p-6 border-b border-hero-grey-200">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold text-hero-black">
            Session Roster
          </h3>
          <div class="text-sm text-hero-grey-600">
            {ParticipationCollection.count_checked_in(@participation_records)} / {length(
              @participation_records
            )} checked in
          </div>
        </div>
      </div>

      <%!-- Roster list --%>
      <div class="divide-y divide-hero-grey-200">
        <div
          :for={record <- @participation_records}
          class="p-4 md:p-6 hover:bg-hero-grey-50 transition-colors"
        >
          <div class="flex items-start justify-between gap-4">
            <%!-- Child info --%>
            <div class="flex-1">
              <div class="font-medium text-hero-black mb-1">
                {record.child_first_name} {record.child_last_name}
              </div>

              <%!-- Check-in/out times --%>
              <div class="space-y-1 text-sm text-hero-grey-600">
                <%= if record.check_in_at do %>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-arrow-right-circle" class="w-4 h-4 text-green-600" />
                    <span>In: {format_time(record.check_in_at)}</span>
                  </div>
                <% end %>
                <%= if record.check_out_at do %>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-arrow-left-circle" class="w-4 h-4 text-hero-blue-600" />
                    <span>Out: {format_time(record.check_out_at)}</span>
                  </div>
                <% end %>
              </div>

              <%!-- Notes (check-in and check-out) --%>
              <%= if Map.get(record, :check_in_notes) || Map.get(record, :check_out_notes) do %>
                <div class="mt-2 space-y-1">
                  <%= if Map.get(record, :check_in_notes) do %>
                    <div class="text-sm text-hero-grey-600 italic">
                      <span class="font-medium text-hero-black-100">Check-in:</span>
                      "{record.check_in_notes}"
                    </div>
                  <% end %>
                  <%= if Map.get(record, :check_out_notes) do %>
                    <div class="text-sm text-hero-grey-600 italic">
                      <span class="font-medium text-hero-black-100">Check-out:</span>
                      "{record.check_out_notes}"
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Status and actions --%>
            <div class="flex flex-col items-end gap-2">
              <.participation_status status={record.status} />
              <%= if @editable && @actions != [] do %>
                <div class="flex gap-2">
                  {render_slot(@actions, record)}
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Checkout form (inline, below child info) --%>
          <%= if @checkout_form_expanded == to_string(record.id) do %>
            <div class="mt-4 border-t border-hero-grey-200 pt-4">
              <.form
                for={Map.get(@checkout_forms, to_string(record.id))}
                id={"checkout-form-#{record.id}"}
                phx-change="update_checkout_notes"
                phx-submit="confirm_checkout"
                phx-value-id={record.id}
              >
                <div class="space-y-3">
                  <%!-- Notes textarea --%>
                  <.input
                    field={Map.get(@checkout_forms, to_string(record.id))[:notes]}
                    type="textarea"
                    label="Check-out notes (optional)"
                    placeholder="E.g., picked up by parent, gave medication reminder..."
                    rows="2"
                  />

                  <%!-- Action buttons --%>
                  <div class="flex gap-2 flex-wrap">
                    <button
                      type="submit"
                      class={[
                        "flex-1 px-4 py-2 bg-hero-blue-600 text-white font-medium hover:bg-hero-blue-700",
                        "focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2",
                        Theme.rounded(:md),
                        Theme.transition(:normal)
                      ]}
                    >
                      Confirm Check Out
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_checkout"
                      phx-value-id={record.id}
                      class={[
                        "px-4 py-2 bg-white text-hero-black-100 font-medium border border-hero-grey-300",
                        "hover:bg-hero-grey-50 focus:outline-none focus:ring-2 focus:ring-hero-blue-500 focus:ring-offset-2",
                        Theme.rounded(:md),
                        Theme.transition(:normal)
                      ]}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          <% end %>
        </div>

        <%!-- Empty state --%>
        <%= if @participation_records == [] do %>
          <div class="p-8 text-center text-hero-grey-500">
            <.icon name="hero-user-group" class="w-12 h-12 mx-auto mb-2 text-hero-grey-400" />
            <p>No children enrolled in this session</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp format_session_datetime(session) do
    date = Map.get(session, :session_date) || Map.get(session, :date) || Date.utc_today()
    start_time = Map.get(session, :start_time) || ~T[00:00:00]

    "#{Calendar.strftime(date, "%B %d, %Y")} at #{Calendar.strftime(start_time, "%I:%M %p")}"
  end

  defp format_time(nil), do: "N/A"

  defp format_time(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  defp format_time(%Time{} = time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  # Status badge helper functions

  defp size_classes(:sm), do: "px-2 py-0.5 text-xs"
  defp size_classes(:md), do: "px-2.5 py-1 text-sm"
  defp size_classes(:lg), do: "px-3 py-1.5 text-base"

  defp icon_size_classes(:sm), do: "w-3 h-3"
  defp icon_size_classes(:md), do: "w-4 h-4"
  defp icon_size_classes(:lg), do: "w-5 h-5"

  defp status_color_classes(:scheduled),
    do: "bg-hero-grey-50 text-hero-black-100 border border-hero-grey-300"

  defp status_color_classes(:in_progress), do: "bg-blue-100 text-blue-700 border border-blue-300"

  defp status_color_classes(:completed), do: "bg-green-100 text-green-700 border border-green-300"

  defp status_color_classes(:checked_in),
    do: "bg-green-100 text-green-700 border border-green-300"

  defp status_color_classes(:checked_out), do: "bg-blue-100 text-blue-700 border border-blue-300"

  defp status_color_classes(:absent), do: "bg-orange-100 text-orange-700 border border-orange-300"

  defp status_color_classes(:expected),
    do: "bg-yellow-100 text-yellow-700 border border-yellow-300"

  defp status_icon(:scheduled), do: "hero-clock"
  defp status_icon(:in_progress), do: "hero-play-circle"
  defp status_icon(:completed), do: "hero-check-circle"
  defp status_icon(:checked_in), do: "hero-check-circle"
  defp status_icon(:checked_out), do: "hero-arrow-left-circle"
  defp status_icon(:absent), do: "hero-x-circle"
  defp status_icon(:expected), do: "hero-clock"

  defp status_label(:scheduled), do: "Scheduled"
  defp status_label(:in_progress), do: "In Progress"
  defp status_label(:completed), do: "Completed"
  defp status_label(:checked_in), do: "Checked In"
  defp status_label(:checked_out), do: "Checked Out"
  defp status_label(:absent), do: "Absent"
  defp status_label(:expected), do: "Expected"
end

defmodule KlassHeroWeb.Admin.VerificationsLive do
  @moduledoc """
  LiveView for admin verification document management.

  Displays verification documents with status filtering and allows admins
  to review provider verification requests. Supports URL-based filtering
  via query params for bookmarkable views.
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Identity
  alias KlassHeroWeb.Theme

  @valid_statuses ~w(pending approved rejected)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Verifications"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = parse_status_filter(params)

    {:ok, results} = Identity.list_verification_documents_for_admin(status)

    socket =
      socket
      |> assign(:current_status, status)
      |> assign(:document_count, length(results))
      |> stream(:documents, results,
        reset: true,
        dom_id: fn %{document: doc} -> "doc-#{doc.id}" end
      )

    {:noreply, socket}
  end

  # Trigger: status param is a known value like "pending"
  # Why: only allow valid status filters, ignore garbage input
  # Outcome: returns atom for valid statuses, nil for "all" or unknown
  defp parse_status_filter(%{"status" => status}) when status in @valid_statuses do
    String.to_existing_atom(status)
  end

  defp parse_status_filter(_params), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen p-4 md:p-6">
      <%!-- Header --%>
      <div class="mb-6">
        <h1 class={[Theme.typography(:section_title), Theme.text_color(:heading)]}>
          {gettext("Verifications")}
        </h1>
        <p class={["mt-1", Theme.typography(:body_small), Theme.text_color(:muted)]}>
          {ngettext(
            "%{count} document",
            "%{count} documents",
            @document_count,
            count: @document_count
          )}
        </p>
      </div>

      <%!-- Filter Tabs --%>
      <nav id="verification-filters" class="flex gap-2 mb-6 overflow-x-auto pb-2">
        <.filter_tab
          label={gettext("All")}
          status={nil}
          current_status={@current_status}
        />
        <.filter_tab
          label={gettext("Pending")}
          status={:pending}
          current_status={@current_status}
        />
        <.filter_tab
          label={gettext("Approved")}
          status={:approved}
          current_status={@current_status}
        />
        <.filter_tab
          label={gettext("Rejected")}
          status={:rejected}
          current_status={@current_status}
        />
      </nav>

      <%!-- Document List --%>
      <div id="documents" phx-update="stream" class="space-y-3">
        <div class="hidden only:block">
          <.documents_empty_state current_status={@current_status} />
        </div>

        <.link
          :for={{dom_id, entry} <- @streams.documents}
          id={dom_id}
          navigate={~p"/admin/verifications/#{entry.document.id}"}
          class={[
            Theme.card_variant(:default),
            "block p-4 hover:bg-gray-50 transition-colors"
          ]}
        >
          <%!-- Mobile: stacked card layout --%>
          <div class="md:hidden space-y-2">
            <div class="flex items-center justify-between">
              <span class="font-semibold text-sm truncate mr-2">
                {entry.provider_business_name}
              </span>
              <.status_badge status={entry.document.status} />
            </div>
            <p class={["text-sm", Theme.text_color(:body)]}>
              {humanize_document_type(entry.document.document_type)}
            </p>
            <div class="flex items-center justify-between">
              <span class={["text-xs truncate mr-2", Theme.text_color(:muted)]}>
                {entry.document.original_filename}
              </span>
              <span class={["text-xs whitespace-nowrap", Theme.text_color(:muted)]}>
                {format_date(entry.document.inserted_at)}
              </span>
            </div>
          </div>

          <%!-- Desktop: row layout --%>
          <div class="hidden md:grid md:grid-cols-12 md:gap-4 md:items-center">
            <span class="col-span-3 font-semibold text-sm truncate">
              {entry.provider_business_name}
            </span>
            <span class={["col-span-3 text-sm", Theme.text_color(:body)]}>
              {humanize_document_type(entry.document.document_type)}
            </span>
            <div class="col-span-2">
              <.status_badge status={entry.document.status} />
            </div>
            <span class={["col-span-2 text-sm truncate", Theme.text_color(:muted)]}>
              {entry.document.original_filename}
            </span>
            <span class={["col-span-2 text-sm text-right", Theme.text_color(:muted)]}>
              {format_date(entry.document.inserted_at)}
            </span>
          </div>
        </.link>
      </div>
    </div>
    """
  end

  # ------------------------------------------------------------------
  # Components
  # ------------------------------------------------------------------

  attr :label, :string, required: true
  attr :status, :atom, required: true
  attr :current_status, :atom, required: true

  defp filter_tab(assigns) do
    ~H"""
    <.link
      patch={filter_path(@status)}
      class={[
        "px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors",
        if(@status == @current_status,
          do: "#{Theme.bg(:primary)} text-white",
          else: "#{Theme.bg(:surface)} #{Theme.text_color(:muted)} hover:bg-gray-100"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      status_classes(@status)
    ]}>
      {humanize_status(@status)}
    </span>
    """
  end

  attr :current_status, :atom, required: true

  defp documents_empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <.icon name="hero-document-magnifying-glass" class={"w-12 h-12 mx-auto mb-4 #{Theme.text_color(:muted)}"} />
      <p class={[Theme.typography(:body), Theme.text_color(:muted)]}>
        {empty_message(@current_status)}
      </p>
    </div>
    """
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp filter_path(nil), do: ~p"/admin/verifications"
  defp filter_path(status), do: ~p"/admin/verifications?status=#{status}"

  defp status_classes(:pending), do: "bg-yellow-100 text-yellow-800"
  defp status_classes(:approved), do: "bg-green-100 text-green-800"
  defp status_classes(:rejected), do: "bg-red-100 text-red-800"

  defp humanize_status(:pending), do: gettext("Pending")
  defp humanize_status(:approved), do: gettext("Approved")
  defp humanize_status(:rejected), do: gettext("Rejected")

  defp humanize_document_type("business_registration"), do: gettext("Business Registration")
  defp humanize_document_type("insurance_certificate"), do: gettext("Insurance Certificate")
  defp humanize_document_type("id_document"), do: gettext("ID Document")
  defp humanize_document_type("tax_certificate"), do: gettext("Tax Certificate")
  defp humanize_document_type("other"), do: gettext("Other")
  defp humanize_document_type(type), do: type

  defp empty_message(nil), do: gettext("No verification documents found.")
  defp empty_message(:pending), do: gettext("No pending documents to review.")
  defp empty_message(:approved), do: gettext("No approved documents.")
  defp empty_message(:rejected), do: gettext("No rejected documents.")

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end
end

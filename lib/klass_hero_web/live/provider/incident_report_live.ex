defmodule KlassHeroWeb.Provider.IncidentReportLive do
  @moduledoc """
  Provider-facing page for submitting an incident report.

  One-of scope: the report is tied to either a program (via `?program_id=`)
  or a session (via `?session_id=`). Invalid preselections redirect to the
  provider dashboard with an error flash.

  Form fields and submit handling are added in subsequent tasks; this
  module currently focuses on mount-time provider resolution, ownership
  validation, and rendering the page chrome.
  """

  use KlassHeroWeb, :live_view

  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHeroWeb.Theme

  @programs_query Application.compile_env!(:klass_hero, [:provider, :for_querying_provider_programs])

  @impl true
  def mount(params, _session, socket) do
    case socket.assigns.current_scope.provider do
      %ProviderProfile{} = provider ->
        mount_for_provider(socket, provider, params)

      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Provider profile not found."))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp mount_for_provider(socket, provider, params) do
    case resolve_preselection(params, provider.id) do
      {:ok, preselected} ->
        programs = @programs_query.list_by_provider(provider.id)

        socket =
          socket
          |> assign(
            page_title: gettext("Report an Incident"),
            provider: provider,
            programs: programs,
            preselected: preselected,
            form: empty_form(preselected)
          )
          |> allow_upload(:photo,
            accept: ~w(.jpg .jpeg .png .webp),
            max_entries: 1,
            max_file_size: 10_000_000
          )

        {:ok, socket}

      {:error, :preselection_invalid} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Program or session not found."))
         |> push_navigate(to: ~p"/provider/dashboard")}
    end
  end

  defp resolve_preselection(%{"program_id" => program_id}, provider_id) when is_binary(program_id) do
    case @programs_query.get_by_id(program_id) do
      {:ok, %{provider_id: ^provider_id} = program} -> {:ok, {:program, program}}
      _ -> {:error, :preselection_invalid}
    end
  end

  defp resolve_preselection(%{"session_id" => session_id}, _provider_id) when is_binary(session_id) do
    # Session-scope preselection wiring lands in a future task.
    {:ok, :none}
  end

  defp resolve_preselection(_params, _provider_id), do: {:ok, :none}

  defp empty_form(preselected) do
    program_id =
      case preselected do
        {:program, program} -> program.program_id
        _ -> nil
      end

    params = %{
      "program_id" => program_id,
      "category" => nil,
      "severity" => nil,
      "description" => "",
      "occurred_at" => nil
    }

    to_form(params, as: "incident")
  end

  defp selected_program_id({:program, program}), do: program.program_id
  defp selected_program_id(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["min-h-screen", Theme.bg(:muted)]}>
      <div class="max-w-2xl mx-auto px-4 sm:px-6 py-8">
        <div class="mb-6">
          <.link
            navigate={~p"/provider/dashboard"}
            class="flex items-center gap-1 text-hero-grey-500 hover:text-hero-grey-700 transition-colors"
          >
            <.icon name="hero-arrow-left-mini" class="w-5 h-5" />
            {gettext("Back to Dashboard")}
          </.link>
        </div>

        <h1 class={Theme.typography(:page_title)}>
          {gettext("Report an Incident")}
        </h1>
        <p class={[
          Theme.typography(:body_small),
          "mt-2 text-hero-grey-600"
        ]}>
          {gettext(
            "Submit a report about an incident during a program or session. All fields are confidential."
          )}
        </p>

        <.form
          for={@form}
          id="incident-report-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-6 space-y-5"
          data-selected-program={selected_program_id(@preselected)}
        >
          <%!-- form fields land in Task 14 --%>
          <p class={Theme.typography(:body_small)}>
            {gettext("Form fields coming next.")}
          </p>
        </.form>
      </div>
    </div>
    """
  end
end

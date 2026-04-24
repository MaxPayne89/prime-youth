defmodule KlassHero.Provider.Application.Commands.Incident.SubmitIncidentReport do
  @moduledoc """
  Use case for a provider submitting an incident report.

  Validates input, verifies program-or-session ownership via Provider-local
  projections (no cross-context synchronous reads), optionally uploads a
  photo to private storage, persists the report, and dispatches an
  `incident_reported` domain event.
  """

  alias KlassHero.Provider.Application.Queries.ProviderProgramQueries
  alias KlassHero.Provider.Domain.Events.ProviderEvents
  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Shared.DomainEventBus
  alias KlassHero.Shared.Storage

  @context KlassHero.Provider

  @repository Application.compile_env!(:klass_hero, [:provider, :for_storing_incident_reports])
  @sessions_query Application.compile_env!(:klass_hero, [:provider, :for_querying_session_details])

  @doc """
  Submits an incident report.

  ## Parameters

  - `:provider_profile_id` — Required. The provider submitting the report.
  - `:reporter_user_id` — Required. The user submitting the report.
  - `:program_id` OR `:session_id` — Required. Exactly one must be set.
  - `:category` — Required. One of `IncidentReport.valid_categories/0`.
  - `:severity` — Required. One of `IncidentReport.valid_severities/0`.
  - `:description` — Required. Free-text (at least 10 characters).
  - `:occurred_at` — Required. `DateTime.t()` (cannot be in the future).
  - `:file_binary` — Optional. Binary content of an attached photo.
  - `:original_filename` — Optional. Original filename of the photo.
  - `:content_type` — Optional. MIME type of the photo (defaults to `image/jpeg`).
  - `:storage_opts` — Optional. Extra options passed to the storage adapter.

  ## Returns

  - `{:ok, IncidentReport.t()}` on success
  - `{:error, keyword() | term()}` on validation, ownership, or persistence failure
  """
  @spec execute(map()) :: {:ok, IncidentReport.t()} | {:error, keyword() | term()}
  def execute(params) when is_map(params) do
    with :ok <- validate_ownership(params),
         {:ok, photo_ref} <- maybe_upload_photo(params),
         {:ok, report} <- build_report(params, photo_ref),
         {:ok, persisted} <- @repository.create(report) do
      publish_event(persisted)
      {:ok, persisted}
    end
  end

  # Trigger: params carry program_id or session_id (one-of scope)
  # Why: ownership is enforced via Provider-local projection — no cross-context sync read
  # Outcome: :ok when the resource belongs to the provider, error otherwise
  defp validate_ownership(%{program_id: pid, provider_profile_id: prov_id}) when is_binary(pid) do
    case ProviderProgramQueries.get_by_id(pid) do
      {:ok, %{provider_id: ^prov_id}} -> :ok
      _ -> {:error, [program_id: "does not belong to this provider"]}
    end
  end

  defp validate_ownership(%{session_id: sid, provider_profile_id: prov_id}) when is_binary(sid) do
    case @sessions_query.get_by_id(sid) do
      {:ok, %{provider_id: ^prov_id}} -> :ok
      _ -> {:error, [session_id: "does not belong to this provider"]}
    end
  end

  defp validate_ownership(_), do: {:error, [target: "exactly one of program_id or session_id must be set"]}

  # Trigger: no photo binary supplied
  # Why: photo is optional; skip storage entirely when nothing to upload
  # Outcome: empty photo_ref returned for downstream report construction
  defp maybe_upload_photo(%{file_binary: nil}), do: {:ok, %{photo_url: nil, original_filename: nil}}

  defp maybe_upload_photo(%{file_binary: file_binary} = params) when is_binary(file_binary) do
    path =
      Storage.build_timestamped_path(
        "incident-reports/providers",
        params.provider_profile_id,
        params[:original_filename],
        "photo.jpg"
      )

    content_type = params[:content_type] || "image/jpeg"
    opts = Keyword.merge([content_type: content_type], params[:storage_opts] || [])

    with {:ok, key} <- Storage.upload(:private, path, file_binary, opts) do
      {:ok, %{photo_url: key, original_filename: params[:original_filename]}}
    end
  end

  defp maybe_upload_photo(_), do: {:ok, %{photo_url: nil, original_filename: nil}}

  defp build_report(params, %{photo_url: url, original_filename: name}) do
    IncidentReport.new(%{
      id: Ecto.UUID.generate(),
      provider_profile_id: params.provider_profile_id,
      reporter_user_id: params.reporter_user_id,
      program_id: params[:program_id],
      session_id: params[:session_id],
      category: params.category,
      severity: params.severity,
      description: params.description,
      occurred_at: params.occurred_at,
      photo_url: url,
      original_filename: name
    })
  end

  defp publish_event(report) do
    event = ProviderEvents.incident_reported(report)
    DomainEventBus.dispatch(@context, event)
  end
end

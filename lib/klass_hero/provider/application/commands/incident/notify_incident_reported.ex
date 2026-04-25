defmodule KlassHero.Provider.Application.Commands.Incident.NotifyIncidentReported do
  @moduledoc """
  Emails a provider's business owner when an incident report is submitted.
  Self-reports (reporter == owner) short-circuit early.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.Models.ProviderProfile
  alias KlassHero.Shared.Storage

  require Logger

  @incident_query Application.compile_env!(:klass_hero, [:provider, :for_querying_incident_reports])
  @profile_query Application.compile_env!(:klass_hero, [:provider, :for_querying_provider_profiles])
  @program_query Application.compile_env!(:klass_hero, [:provider, :for_querying_provider_programs])
  @notifier Application.compile_env!(:klass_hero, [:provider, :for_sending_incident_emails])

  @signed_url_ttl_seconds 3600
  @program_fallback_label "a program"
  @session_fallback_label "a session"

  @doc """
  Sends the incident-report email for the given report id.

  Returns `:ok` on success or self-report skip; `{:error, reason}` on
  recoverable failure (Oban retries) or permanent failure.
  """
  @spec execute(%{required(:incident_report_id) => binary()}) :: :ok | {:error, atom()}
  def execute(%{incident_report_id: id}) when is_binary(id) do
    with {:ok, report} <- fetch_report(id),
         {:ok, profile} <- fetch_profile(report.provider_profile_id),
         :continue <- check_self_report(report, profile, id),
         {:ok, email} <- require_owner_email(profile, id) do
      program_label = resolve_program_label(report)
      signed_url = maybe_sign_photo(report, id)
      send_email(profile, email, report, program_label, signed_url)
    end
  end

  defp fetch_report(id) do
    case @incident_query.get(id) do
      {:ok, %IncidentReport{} = report} -> {:ok, report}
      {:error, :not_found} -> {:error, :incident_report_not_found}
    end
  end

  defp fetch_profile(provider_profile_id) do
    case @profile_query.get(provider_profile_id) do
      {:ok, %ProviderProfile{} = profile} -> {:ok, profile}
      {:error, :not_found} -> {:error, :provider_profile_not_found}
    end
  end

  defp check_self_report(%IncidentReport{reporter_user_id: rid}, %ProviderProfile{identity_id: iid}, id)
       when rid == iid do
    Logger.info("[NotifyIncidentReported] Skipping self-report",
      incident_report_id: id,
      identity_id: iid
    )

    :ok
  end

  defp check_self_report(_report, _profile, _id), do: :continue

  defp require_owner_email(%ProviderProfile{business_owner_email: email}, _id)
       when is_binary(email) and byte_size(email) > 0 do
    {:ok, email}
  end

  defp require_owner_email(%ProviderProfile{id: profile_id}, id) do
    Logger.warning("[NotifyIncidentReported] Missing business_owner_email",
      incident_report_id: id,
      provider_profile_id: profile_id
    )

    {:error, :missing_business_owner_email}
  end

  defp resolve_program_label(%IncidentReport{program_id: pid}) when is_binary(pid) do
    case @program_query.get_by_id(pid) do
      {:ok, %{name: name}} when is_binary(name) and byte_size(name) > 0 ->
        name

      {:error, :not_found} ->
        Logger.warning("[NotifyIncidentReported] Program not found, using fallback label",
          program_id: pid
        )

        @program_fallback_label
    end
  end

  defp resolve_program_label(%IncidentReport{}), do: @session_fallback_label

  defp maybe_sign_photo(%IncidentReport{photo_url: nil}, _id), do: nil

  defp maybe_sign_photo(%IncidentReport{photo_url: key}, id) when is_binary(key) do
    case Storage.signed_url(:private, key, @signed_url_ttl_seconds) do
      {:ok, url} ->
        url

      {:error, reason} ->
        Logger.warning("[NotifyIncidentReported] Photo signing failed, sending without photo",
          incident_report_id: id,
          reason: inspect(reason)
        )

        nil
    end
  end

  defp send_email(profile, email, report, program_label, signed_url) do
    recipient = %{email: email, name: profile.business_name}

    context = %{
      program_name: program_label,
      signed_photo_url: signed_url,
      business_name: profile.business_name
    }

    case @notifier.send_incident_report(recipient, report, context) do
      {:ok, _email} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end

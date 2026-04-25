defmodule KlassHero.Provider.Domain.Ports.ForQueryingIncidentReports do
  @moduledoc """
  Read-only port for querying incident reports in the Provider bounded context.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.ReadModels.IncidentReportSummary

  @doc """
  Retrieves an incident report by its ID.

  Returns:
  - `{:ok, IncidentReport.t()}` when the report is found
  - `{:error, :not_found}` when no report exists with the given ID
  """
  @callback get(id :: binary()) :: {:ok, IncidentReport.t()} | {:error, :not_found}

  @doc """
  Lists incident report summaries for a program owned by the given provider.

  Combines program-direct reports (`incident_reports.program_id` matches) with
  session-linked reports (sessions of the program, joined through the
  `provider_session_details` projection). Results are ordered by
  `occurred_at` descending. Provider scoping is enforced in both branches —
  passing a foreign provider's `program_id` returns `[]`.
  """
  @callback list_for_program(provider_id :: binary(), program_id :: binary()) ::
              [IncidentReportSummary.t()]
end

defmodule KlassHero.Provider.Application.Queries.IncidentReportQueries do
  @moduledoc """
  Read-side queries for incident reports.

  Consumers in the web layer reach this module via `KlassHero.Provider`'s
  public API.
  """

  alias KlassHero.Provider.Domain.ReadModels.IncidentReportSummary

  @repository Application.compile_env!(:klass_hero, [:provider, :for_querying_incident_reports])

  @doc """
  Lists incident report summaries for a program owned by the given provider,
  ordered by `occurred_at` descending. Includes both program-direct and
  session-linked reports. Provider scoping is enforced — passing a foreign
  provider's program ID returns `[]`.
  """
  @spec list_for_program(Ecto.UUID.t(), Ecto.UUID.t()) :: [IncidentReportSummary.t()]
  def list_for_program(provider_id, program_id) when is_binary(provider_id) and is_binary(program_id) do
    @repository.list_for_program(provider_id, program_id)
  end
end

defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.IncidentReportRepository do
  @moduledoc """
  Ecto-based repository for incident reports.

  Implements both `ForStoringIncidentReports` (writes) and
  `ForQueryingIncidentReports` (reads). Domain mapping via
  `IncidentReportMapper`. Infrastructure errors crash and are handled
  by the supervision tree.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForQueryingIncidentReports
  @behaviour KlassHero.Provider.Domain.Ports.ForStoringIncidentReports

  use KlassHero.Shared.Tracing

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.IncidentReportMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Provider.Domain.Ports.ForQueryingIncidentReports
  alias KlassHero.Provider.Domain.Ports.ForStoringIncidentReports
  alias KlassHero.Repo

  @impl ForStoringIncidentReports
  @doc """
  Creates a new incident report in the database.

  Returns:
  - `{:ok, IncidentReport.t()}` on success
  - `{:error, Ecto.Changeset.t()}` on validation or FK failure
  """
  def create(report) do
    span do
      set_attributes("db", operation: "insert", entity: "incident_report")

      attrs = IncidentReportMapper.to_schema(report)
      changeset = IncidentReportSchema.changeset(%IncidentReportSchema{}, attrs)

      with {:ok, saved} <- Repo.insert(changeset) do
        {:ok, IncidentReportMapper.to_domain(saved)}
      end
    end
  end

  @impl ForQueryingIncidentReports
  @doc """
  Retrieves an incident report by its ID.

  Returns:
  - `{:ok, IncidentReport.t()}` when found
  - `{:error, :not_found}` when no report exists with the given ID
  """
  def get(id) when is_binary(id) do
    span do
      set_attributes("db", operation: "select", entity: "incident_report")

      case Repo.get(IncidentReportSchema, id) do
        nil -> {:error, :not_found}
        schema -> {:ok, IncidentReportMapper.to_domain(schema)}
      end
    end
  end
end

defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.IncidentReportRepository do
  @moduledoc """
  Ecto-based repository for incident reports.

  Implements the ForStoringIncidentReports port with:
  - Domain entity mapping via IncidentReportMapper
  - Idiomatic "let it crash" error handling

  Infrastructure errors (connection, query) are not caught — they crash and
  are handled by the supervision tree.
  """

  @behaviour KlassHero.Provider.Domain.Ports.ForStoringIncidentReports

  use KlassHero.Shared.Tracing

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.IncidentReportMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.IncidentReportSchema
  alias KlassHero.Repo

  @impl true
  @doc """
  Creates a new incident report in the database.

  Returns:
  - `{:ok, IncidentReport.t()}` on success
  - `{:error, Ecto.Changeset.t()}` on validation or FK failure
  """
  def create(report) do
    span do
      set_attributes("db", operation: "insert", entity: "incident_report")

      attrs = IncidentReportMapper.to_schema_attrs(report)
      changeset = IncidentReportSchema.changeset(%IncidentReportSchema{}, attrs)

      with {:ok, saved} <- Repo.insert(changeset) do
        {:ok, IncidentReportMapper.to_domain(saved)}
      end
    end
  end
end

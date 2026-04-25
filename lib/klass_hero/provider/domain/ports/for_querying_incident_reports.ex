defmodule KlassHero.Provider.Domain.Ports.ForQueryingIncidentReports do
  @moduledoc """
  Read-only port for querying incident reports in the Provider bounded context.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @doc """
  Retrieves an incident report by its ID.

  Returns:
  - `{:ok, IncidentReport.t()}` when the report is found
  - `{:error, :not_found}` when no report exists with the given ID
  """
  @callback get(id :: binary()) :: {:ok, IncidentReport.t()} | {:error, :not_found}
end

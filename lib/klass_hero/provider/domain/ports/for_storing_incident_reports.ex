defmodule KlassHero.Provider.Domain.Ports.ForStoringIncidentReports do
  @moduledoc """
  Driven port for persisting incident reports in the Provider bounded context.

  ## Expected Return Values

  - `create/1` - Returns `{:ok, IncidentReport.t()}` on success or
    `{:error, Ecto.Changeset.t()}` on validation/FK failure.

  Infrastructure errors (connection, query) are not caught — they crash and
  are handled by the supervision tree.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @doc """
  Persists a new incident report.

  Returns:
  - `{:ok, IncidentReport.t()}` - Report stored successfully
  - `{:error, Ecto.Changeset.t()}` - Validation or persistence failure
  """
  @callback create(IncidentReport.t()) ::
              {:ok, IncidentReport.t()} | {:error, Ecto.Changeset.t()}
end

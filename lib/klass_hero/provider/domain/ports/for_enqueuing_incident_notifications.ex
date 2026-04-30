defmodule KlassHero.Provider.Domain.Ports.ForEnqueuingIncidentNotifications do
  @moduledoc """
  Driven port for scheduling the incident-notification email job.

  Called from `SubmitIncidentReport` *inside* the persistence transaction so
  the report row and the email job commit atomically. Adapters wrap the
  underlying queue insert (Oban) and surface failures as a tuple — never
  raise — so the calling `with` chain can roll back cleanly.

  ## Expected Return Values

  - `enqueue/1` — Returns `{:ok, Oban.Job.t()}` on success or
    `{:error, term()}` on enqueue failure (DB error, validation, etc.).
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @doc """
  Schedules the notification job for a freshly persisted incident report.

  Implementations must NOT raise on enqueue failure — return `{:error, _}`
  so the caller's transaction can roll back the report row.
  """
  @callback enqueue(IncidentReport.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
end

defmodule KlassHero.Provider.Domain.Ports.ForEnqueuingIncidentNotifications do
  @moduledoc """
  Driven port for scheduling the incident-notification email job.

  Called from `SubmitIncidentReport` *inside* the persistence transaction so
  the report row and the email job commit atomically. Adapters wrap the
  underlying queue insert (Oban) and surface failures as a tuple — never
  raise — so the calling `with` chain can roll back cleanly.

  ## Expected Return Values

  - `enqueue/1` — Returns `{:ok, Oban.Job.t()}` on success.
  - On failure, returns `{:error, reason}` where `reason` is typically:
    - `Ecto.Changeset.t()` — Oban rejected the job args via its own changeset
      (invalid worker, malformed args, unique-constraint violation when
      uniqueness opts are configured).
    - `term()` — DB error or transport failure surfaced by `Oban.insert/1`.
    Test stubs may also return arbitrary atoms (e.g. `:enqueue_failed`) to
    exercise the caller's rollback path.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport

  @doc """
  Schedules the notification job for a freshly persisted incident report.

  Implementations must NOT raise on enqueue failure — return `{:error, _}`
  so the caller's transaction can roll back the report row.
  """
  @callback enqueue(IncidentReport.t()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | term()}
end

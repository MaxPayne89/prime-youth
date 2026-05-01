defmodule KlassHero.Provider.Domain.Ports.ForSchedulingIncidentNotifications do
  @moduledoc """
  Driven port for scheduling the incident-notification email job.

  Called from `SubmitIncidentReport` *inside* the persistence transaction so
  the report row and the email job commit atomically. Adapters wrap the
  underlying queue insert (Oban) and surface failures as a tuple — never
  raise — so the calling `with` chain can roll back cleanly.

  Verb choice mirrors `Messaging.Domain.Ports.ForSchedulingEmailJobs` —
  both ports cover "create an Oban job", and the codebase aligns on
  `Scheduling` as the verb for that act.

  ## Expected Return Values

  - `schedule/2` — Returns `{:ok, Oban.Job.t()}` on success.
  - On failure, returns `{:error, reason}` where `reason` is typically:
    - `Ecto.Changeset.t()` — Oban rejected the job args via its own changeset
      (invalid worker, malformed args, unique-constraint violation when
      uniqueness opts are configured).
    - `term()` — DB error or transport failure surfaced by `Oban.insert/1`.
    Test stubs may also return arbitrary atoms (e.g. `:enqueue_failed`) to
    exercise the caller's rollback path.
  """

  alias KlassHero.Provider.Domain.Models.IncidentReport
  alias KlassHero.Provider.Domain.Models.ProviderProfile

  @doc """
  Schedules the notification job for a freshly persisted incident report.

  The provider profile is passed in alongside the report so its
  `business_owner_email` and `business_name` can travel on the Oban job
  args — the email worker uses them directly without a profile DB lookup.

  Implementations must NOT raise on failure — return `{:error, _}` so the
  caller's transaction can roll back the report row.
  """
  @callback schedule(IncidentReport.t(), ProviderProfile.t()) ::
              {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t() | term()}
end

defmodule KlassHero.Messaging.Application.Commands.ScheduleEmailContentFetch do
  @moduledoc """
  Command for scheduling a content fetch retry for an inbound email.
  """

  @email_job_scheduler Application.compile_env!(:klass_hero, [
                         :messaging,
                         :for_scheduling_email_jobs
                       ])

  @doc """
  Schedules a content fetch for an inbound email.

  ## Parameters
  - email_id: The inbound email ID
  - resend_id: The Resend email ID for the API call

  ## Returns
  - `{:ok, term()}` - Job scheduled
  - `{:error, reason}` - Scheduling failed
  """
  @spec execute(String.t(), String.t()) :: {:ok, term()} | {:error, term()}
  def execute(email_id, resend_id) do
    @email_job_scheduler.schedule_content_fetch(email_id, resend_id)
  end
end

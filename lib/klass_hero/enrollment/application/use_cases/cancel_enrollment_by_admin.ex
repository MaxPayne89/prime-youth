defmodule KlassHero.Enrollment.Application.UseCases.CancelEnrollmentByAdmin do
  @moduledoc """
  Cancels an enrollment by admin action.

  Loads the enrollment, applies the domain cancellation (with lifecycle guards),
  persists the change, and dispatches an enrollment_cancelled domain event.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.Enrollment
  alias KlassHero.Shared.DomainEventBus

  require Logger

  @context KlassHero.Enrollment

  @enrollment_repo Application.compile_env!(
                     :klass_hero,
                     [:enrollment, :for_managing_enrollments]
                   )

  @doc """
  Cancels an enrollment identified by `enrollment_id`.

  ## Parameters

  - `enrollment_id` — UUID of the enrollment to cancel
  - `admin_id` — UUID of the admin performing the cancellation
  - `reason` — human-readable cancellation reason (required)

  ## Returns

  - `{:ok, Enrollment.t()}` — cancellation succeeded
  - `{:error, :not_found}` — enrollment does not exist
  - `{:error, :invalid_status_transition}` — enrollment is completed or already cancelled
  """
  @spec execute(String.t(), String.t(), String.t()) ::
          {:ok, Enrollment.t()} | {:error, :not_found | :invalid_status_transition | term()}
  def execute(enrollment_id, admin_id, reason)
      when is_binary(enrollment_id) and is_binary(admin_id) and is_binary(reason) do
    with {:ok, enrollment} <- @enrollment_repo.get_by_id(enrollment_id),
         {:ok, cancelled} <- Enrollment.cancel(enrollment, reason),
         attrs = %{
           status: Atom.to_string(cancelled.status),
           cancelled_at: cancelled.cancelled_at,
           cancellation_reason: cancelled.cancellation_reason
         },
         {:ok, persisted} <- @enrollment_repo.update(enrollment_id, attrs) do
      dispatch_event(persisted, admin_id, reason)

      Logger.info("[Enrollment.CancelByAdmin] Enrollment cancelled by admin",
        enrollment_id: enrollment_id,
        admin_id: admin_id
      )

      {:ok, persisted}
    end
  end

  defp dispatch_event(enrollment, admin_id, reason) do
    EnrollmentEvents.enrollment_cancelled(enrollment.id, %{
      enrollment_id: enrollment.id,
      program_id: enrollment.program_id,
      child_id: enrollment.child_id,
      parent_id: enrollment.parent_id,
      admin_id: admin_id,
      reason: reason,
      cancelled_at: enrollment.cancelled_at
    })
    |> then(&DomainEventBus.dispatch(@context, &1))
  end
end

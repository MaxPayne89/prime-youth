defmodule KlassHero.Enrollment.Application.Commands.CancelEnrollmentByAdmin do
  @moduledoc """
  Cancels an enrollment by admin action.

  Loads the enrollment, applies the domain cancellation (with lifecycle guards),
  persists the change, and dispatches an enrollment_cancelled domain event.
  """

  alias KlassHero.Enrollment.Domain.Events.EnrollmentEvents
  alias KlassHero.Enrollment.Domain.Models.Enrollment
  alias KlassHero.Shared.EventDispatchHelper

  require Logger

  @context KlassHero.Enrollment

  @enrollment_reader Application.compile_env!(
                       :klass_hero,
                       [:enrollment, :for_querying_enrollments]
                     )
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
  - `{:error, :invalid_reason}` — reason is empty
  """
  @spec execute(String.t(), String.t(), String.t()) ::
          {:ok, Enrollment.t()}
          | {:error, :not_found | :invalid_status_transition | :invalid_reason | term()}
  def execute(enrollment_id, admin_id, reason)
      when is_binary(enrollment_id) and is_binary(admin_id) and is_binary(reason) and byte_size(reason) > 0 do
    with {:ok, enrollment} <- @enrollment_reader.get_by_id(enrollment_id),
         {:ok, cancelled} <- Enrollment.cancel(enrollment, reason),
         {:ok, persisted} <-
           @enrollment_repo.update(enrollment_id, %{
             status: Atom.to_string(cancelled.status),
             cancelled_at: cancelled.cancelled_at,
             cancellation_reason: cancelled.cancellation_reason
           }),
         :ok <-
           EnrollmentEvents.enrollment_cancelled(persisted.id, %{
             enrollment_id: persisted.id,
             program_id: persisted.program_id,
             child_id: persisted.child_id,
             parent_id: persisted.parent_id,
             admin_id: admin_id,
             reason: reason,
             cancelled_at: persisted.cancelled_at
           })
           |> EventDispatchHelper.dispatch_or_error(@context) do
      Logger.info("[Enrollment.CancelByAdmin] Enrollment cancelled by admin",
        enrollment_id: enrollment_id,
        admin_id: admin_id
      )

      {:ok, persisted}
    end
  end

  def execute(enrollment_id, admin_id, reason)
      when is_binary(enrollment_id) and is_binary(admin_id) and is_binary(reason) do
    {:error, :invalid_reason}
  end
end

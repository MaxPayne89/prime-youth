defmodule KlassHero.Enrollment.Application.UseCases.CreateEnrollment do
  @moduledoc """
  Use case for creating a new enrollment.

  This use case orchestrates:
  1. Validation of parent profile existence
  2. Validation of booking entitlement (tier-based limits)
  3. Validation of participant eligibility (age, gender, grade restrictions)
  4. Persistence via the repository port

  ## Required Parameters

  - identity_id: The user's identity ID (for validation) OR parent_id (direct)
  - program_id: UUID of the program to enroll in
  - child_id: UUID of the child being enrolled

  ## Optional Parameters

  - status: Enrollment status (defaults to "pending")
  - enrolled_at: DateTime of enrollment (defaults to now)
  - subtotal, vat_amount, card_fee_amount, total_amount: Fee amounts
  - payment_method: "card" or "transfer"
  - special_requirements: Special needs or requirements text

  ## Validation

  When `identity_id` is provided, the use case validates:
  - Parent profile exists for the identity
  - Parent has remaining booking capacity based on their tier

  When only `parent_id` is provided (direct calls), validation is skipped.
  """

  alias KlassHero.Enrollment
  alias KlassHero.Enrollment.Domain.Models.Enrollment, as: EnrollmentModel
  alias KlassHero.Entitlements
  alias KlassHero.Family

  require Logger

  @doc """
  Creates a new enrollment.

  Returns:
  - `{:ok, Enrollment.t()}` on success
  - `{:error, :no_parent_profile}` if no parent profile exists for identity
  - `{:error, :booking_limit_exceeded}` if monthly booking cap reached
  - `{:error, :ineligible, [String.t()]}` if child fails participant restrictions
  - `{:error, :processing_failed}` if eligibility check fails unexpectedly
  - `{:error, :duplicate_resource}` if active enrollment exists for child/program
  - `{:error, term()}` on validation or persistence failure
  """
  @spec execute(map()) ::
          {:ok, EnrollmentModel.t()} | {:error, :ineligible, [String.t()]} | {:error, term()}
  def execute(%{identity_id: identity_id} = params) when is_binary(identity_id) do
    create_enrollment_with_validation(identity_id, params)
  end

  def execute(params) when is_map(params) do
    create_enrollment_direct(params)
  end

  defp create_enrollment_with_validation(identity_id, params) do
    with {:ok, parent} <- validate_parent_profile(identity_id),
         :ok <- validate_booking_entitlement(parent),
         :ok <- validate_participant_eligibility(params[:program_id], params[:child_id]) do
      attrs = build_enrollment_attrs(params, parent.id)

      Logger.info("[Enrollment.CreateEnrollment] Creating enrollment with validation",
        program_id: attrs[:program_id],
        child_id: attrs[:child_id],
        parent_id: attrs[:parent_id]
      )

      # Trigger: capacity check and enrollment creation happen atomically
      # Why: prevents TOCTOU race where concurrent requests both pass check
      # Outcome: SELECT FOR UPDATE on policy row serializes concurrent attempts
      repository().create_with_capacity_check(attrs, params[:program_id])
    end
  end

  defp create_enrollment_direct(params) do
    attrs = build_enrollment_attrs(params, params[:parent_id])

    Logger.info("[Enrollment.CreateEnrollment] Creating enrollment (direct)",
      program_id: attrs[:program_id],
      child_id: attrs[:child_id],
      parent_id: attrs[:parent_id]
    )

    repository().create_with_capacity_check(attrs, params[:program_id])
  end

  defp validate_parent_profile(identity_id) do
    case Family.get_parent_by_identity(identity_id) do
      {:ok, parent} -> {:ok, parent}
      {:error, :not_found} -> {:error, :no_parent_profile}
    end
  end

  defp validate_booking_entitlement(parent) do
    current_count = Enrollment.count_monthly_bookings(parent.id)

    if Entitlements.can_create_booking?(parent, current_count) do
      :ok
    else
      Logger.info("[Enrollment.CreateEnrollment] Booking limit exceeded",
        parent_id: parent.id,
        tier: parent.subscription_tier,
        current_count: current_count
      )

      {:error, :booking_limit_exceeded}
    end
  end

  # Trigger: child may not meet program's age/gender/grade restrictions
  # Why: enforce provider-configured eligibility rules before accepting enrollment
  # Outcome: blocks ineligible children with human-readable reasons
  defp validate_participant_eligibility(program_id, child_id) do
    alias KlassHero.Enrollment.Application.UseCases.CheckParticipantEligibility

    case CheckParticipantEligibility.execute(program_id, child_id) do
      {:ok, :eligible} ->
        :ok

      {:error, :ineligible, reasons} ->
        {:error, :ineligible, reasons}

      {:error, reason} ->
        Logger.warning("[Enrollment.CreateEnrollment] Eligibility check failed unexpectedly",
          program_id: program_id,
          child_id: child_id,
          reason: inspect(reason)
        )

        # Trigger: ACL failure (child not found, etc.)
        # Why: fail closed — deny enrollment if we can't verify eligibility
        # Outcome: return processing_failed so UI shows generic error
        {:error, :processing_failed}
    end
  end

  defp build_enrollment_attrs(params, parent_id) do
    %{
      program_id: params[:program_id],
      child_id: params[:child_id],
      parent_id: parent_id,
      status: params[:status] || "pending",
      enrolled_at: params[:enrolled_at] || DateTime.utc_now(),
      subtotal: params[:subtotal],
      vat_amount: params[:vat_amount],
      card_fee_amount: params[:card_fee_amount],
      total_amount: params[:total_amount],
      payment_method: params[:payment_method],
      special_requirements: params[:special_requirements]
    }
  end

  defp repository do
    Application.get_env(:klass_hero, :enrollment)[:for_managing_enrollments]
  end
end

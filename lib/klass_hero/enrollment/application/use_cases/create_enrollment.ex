defmodule KlassHero.Enrollment.Application.UseCases.CreateEnrollment do
  @moduledoc """
  Use case for creating a new enrollment.

  This use case orchestrates:
  1. Validation of enrollment data
  2. Persistence via the repository port

  ## Required Parameters

  - program_id: UUID of the program to enroll in
  - child_id: UUID of the child being enrolled
  - parent_id: UUID of the parent making the enrollment

  ## Optional Parameters

  - status: Enrollment status (defaults to "pending")
  - enrolled_at: DateTime of enrollment (defaults to now)
  - subtotal, vat_amount, card_fee_amount, total_amount: Fee amounts
  - payment_method: "card" or "transfer"
  - special_requirements: Special needs or requirements text
  """

  alias KlassHero.Enrollment.Domain.Models.Enrollment

  require Logger

  @doc """
  Creates a new enrollment.

  Returns:
  - `{:ok, Enrollment.t()}` on success
  - `{:error, :duplicate_resource}` if active enrollment exists for child/program
  - `{:error, term()}` on validation or persistence failure
  """
  @spec execute(map()) :: {:ok, Enrollment.t()} | {:error, term()}
  def execute(params) when is_map(params) do
    attrs = build_enrollment_attrs(params)

    Logger.info("[Enrollment.CreateEnrollment] Creating enrollment",
      program_id: attrs[:program_id],
      child_id: attrs[:child_id],
      parent_id: attrs[:parent_id]
    )

    repository().create(attrs)
  end

  defp build_enrollment_attrs(params) do
    %{
      program_id: params[:program_id],
      child_id: params[:child_id],
      parent_id: params[:parent_id],
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

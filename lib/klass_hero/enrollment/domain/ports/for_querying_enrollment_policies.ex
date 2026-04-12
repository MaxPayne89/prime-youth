defmodule KlassHero.Enrollment.Domain.Ports.ForQueryingEnrollmentPolicies do
  @moduledoc """
  Read-only port for querying enrollment policies in the Enrollment bounded context.

  Defines the contract for enrollment policy read operations (CQRS query side).
  Write operations remain in `ForManagingEnrollmentPolicies`.
  """

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @doc """
  Retrieves the enrollment policy for a program.
  """
  @callback get_by_program_id(program_id :: binary()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, :not_found}

  @doc """
  Retrieves enrollment policies for multiple programs in a single batch query.

  Returns a map of `program_id => EnrollmentPolicy.t()`.
  Programs without a policy are not included in the result.
  """
  @callback get_policies_by_program_ids(program_ids :: [binary()]) ::
              %{binary() => EnrollmentPolicy.t()}

  @doc """
  Returns the count of active enrollments for a program.
  Active means status is 'pending' or 'confirmed'.
  """
  @callback count_active_enrollments(program_id :: binary()) :: non_neg_integer()

  @doc """
  Returns counts of active enrollments for multiple programs in a single batch query.

  Returns a map of `program_id => count`.
  Programs with no enrollments will have count 0.
  """
  @callback count_active_enrollments_batch(program_ids :: [binary()]) ::
              %{binary() => non_neg_integer()}
end

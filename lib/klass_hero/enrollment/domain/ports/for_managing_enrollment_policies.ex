defmodule KlassHero.Enrollment.Domain.Ports.ForManagingEnrollmentPolicies do
  @moduledoc """
  Port defining the contract for enrollment policy persistence.

  Implementations handle storing and retrieving enrollment capacity
  configuration (min/max enrollment) for programs.
  """

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @doc """
  Creates or updates an enrollment policy for a program.
  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """
  @callback upsert(attrs :: map()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, term()}

  @doc """
  Retrieves the enrollment policy for a program.
  """
  @callback get_by_program_id(program_id :: binary()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, :not_found}

  @doc """
  Returns the remaining enrollment capacity for a program.

  Calculates: max_enrollment - count(active enrollments).
  Returns :unlimited when no max_enrollment is configured.
  """
  @callback get_remaining_capacity(program_id :: binary()) ::
              {:ok, non_neg_integer() | :unlimited}

  @doc """
  Returns the count of active enrollments for a program.
  Active means status is 'pending' or 'confirmed'.
  """
  @callback count_active_enrollments(program_id :: binary()) :: non_neg_integer()
end

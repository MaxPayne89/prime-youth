defmodule KlassHero.Enrollment.Domain.Ports.ForManagingEnrollmentPolicies do
  @moduledoc """
  Write-only port for managing enrollment policies in the Enrollment bounded context.

  Defines the contract for enrollment policy write operations (CQRS command side).
  Read operations have been moved to `ForQueryingEnrollmentPolicies`.
  """

  alias KlassHero.Enrollment.Domain.Models.EnrollmentPolicy

  @doc """
  Creates or updates an enrollment policy for a program.
  Uses upsert semantics — if a policy already exists for the program_id, it is updated.
  """
  @callback upsert(attrs :: map()) ::
              {:ok, EnrollmentPolicy.t()} | {:error, term()}
end

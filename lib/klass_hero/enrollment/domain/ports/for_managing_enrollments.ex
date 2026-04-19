defmodule KlassHero.Enrollment.Domain.Ports.ForManagingEnrollments do
  @moduledoc """
  Write-only port for managing enrollments in the Enrollment bounded context.

  Defines the contract for enrollment write operations (CQRS command side).
  Read operations have been moved to `ForQueryingEnrollments`.
  """

  alias KlassHero.Enrollment.Domain.Models.Enrollment

  @doc """
  Creates a new enrollment in the repository.

  Accepts a map with enrollment attributes.

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment created successfully
  - `{:error, :duplicate_resource}` - Active enrollment already exists for this child/program
  - `{:error, changeset}` - Validation failure
  """
  @callback create(attrs :: map()) ::
              {:ok, Enrollment.t()} | {:error, :duplicate_resource | term()}

  @doc """
  Creates an enrollment with atomic capacity check.

  Locks the enrollment policy row (SELECT FOR UPDATE), verifies remaining
  capacity, and creates the enrollment — all within a single transaction.

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment created successfully
  - `{:error, :program_full}` - Max enrollment capacity reached
  - `{:error, :duplicate_resource}` - Active enrollment already exists for this child/program
  - `{:error, term()}` - Other validation or persistence failure
  """
  @callback create_with_capacity_check(attrs :: map(), program_id :: binary()) ::
              {:ok, Enrollment.t()} | {:error, :program_full | :duplicate_resource | term()}

  @doc """
  Updates an existing enrollment by ID.

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment updated successfully
  - `{:error, :not_found}` - No enrollment exists with the given ID
  - `{:error, changeset}` - Validation failure
  """
  @callback update(id :: binary(), attrs :: map()) ::
              {:ok, Enrollment.t()} | {:error, :not_found | term()}
end

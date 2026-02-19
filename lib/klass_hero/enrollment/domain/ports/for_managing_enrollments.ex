defmodule KlassHero.Enrollment.Domain.Ports.ForManagingEnrollments do
  @moduledoc """
  Repository port for managing enrollments in the Enrollment bounded context.

  This is a behaviour (interface) that defines the contract for enrollment persistence.
  It is implemented by adapters in the infrastructure layer (e.g., Ecto repositories).

  ## Expected Return Values

  - `create/1` - Returns `{:ok, Enrollment.t()}` or domain errors
  - `get_by_id/1` - Returns `{:ok, Enrollment.t()}` or `{:error, :not_found}`
  - `list_by_parent/1` - Returns list of Enrollment.t() (empty list if none)
  - `count_monthly_bookings/3` - Returns non_neg_integer()

  Infrastructure errors (connection, query) are not caught - they crash and
  are handled by the supervision tree.
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
  Retrieves an enrollment by ID.

  Returns:
  - `{:ok, Enrollment.t()}` - Enrollment found
  - `{:error, :not_found}` - No enrollment exists with the given ID
  """
  @callback get_by_id(id :: binary()) ::
              {:ok, Enrollment.t()} | {:error, :not_found}

  @doc """
  Lists all enrollments for a parent.

  Returns list of Enrollment.t(), empty list if none found.
  Results are ordered by enrolled_at descending (most recent first).
  """
  @callback list_by_parent(parent_id :: binary()) :: [Enrollment.t()]

  @doc """
  Counts monthly bookings for a parent within a date range.

  Only counts active enrollments (pending or confirmed).

  Parameters:
  - parent_id: The parent's ID
  - start_date: Start of the date range (inclusive)
  - end_date: End of the date range (inclusive)

  Returns non-negative integer count.
  """
  @callback count_monthly_bookings(
              parent_id :: binary(),
              start_date :: Date.t(),
              end_date :: Date.t()
            ) :: non_neg_integer()

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
  Returns the identity IDs of parents with active enrollments for a program.

  Active enrollments are those with status "pending" or "confirmed".
  Returns a distinct list of identity_ids (user IDs).
  """
  @callback list_enrolled_identity_ids(program_id :: binary()) :: [String.t()]

  @doc """
  Checks if a parent (identified by identity_id) has an active enrollment
  in a program.

  Returns true if at least one active enrollment exists for the given
  program and parent identity.
  """
  @callback enrolled?(program_id :: binary(), identity_id :: binary()) :: boolean()

  @doc """
  Lists active enrollments for a program.

  Active enrollments are those with status "pending" or "confirmed".
  Returns list of Enrollment.t(), ordered by enrolled_at descending.
  """
  @callback list_by_program(program_id :: binary()) :: [Enrollment.t()]
end

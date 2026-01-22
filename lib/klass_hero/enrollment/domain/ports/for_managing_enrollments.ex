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
end

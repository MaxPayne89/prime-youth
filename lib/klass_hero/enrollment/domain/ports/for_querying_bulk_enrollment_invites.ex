defmodule KlassHero.Enrollment.Domain.Ports.ForQueryingBulkEnrollmentInvites do
  @moduledoc """
  Read-only port for querying bulk enrollment invites in the Enrollment bounded context.

  Defines the contract for invite read operations (CQRS query side).
  Write operations remain in `ForStoringBulkEnrollmentInvites`.
  """

  @doc """
  Retrieves a single invite by its ID.

  Returns the invite struct or nil if not found.
  """
  @callback get_by_id(binary()) :: struct() | nil

  @doc """
  Retrieves a single invite by its invite token.

  Returns the invite domain struct or nil if not found.
  """
  @callback get_by_token(binary() | nil) :: struct() | nil

  @doc """
  Returns pending invites that have not yet been assigned an invite token.

  Filters by program IDs, status "pending", and nil invite_token.
  Returns an empty list when given an empty list of program IDs.
  """
  @callback list_pending_without_token([binary()]) :: [struct()]

  @doc """
  Returns all invites for a given program, ordered alphabetically
  by child last name then first name.
  """
  @callback list_by_program(binary()) :: [struct()]

  @doc """
  Returns the count of invites for a given program.
  """
  @callback count_by_program(binary()) :: non_neg_integer()

  @doc """
  Returns existing invite keys for the given program IDs.

  Used for duplicate detection before batch insert. Returns a MapSet
  of `{program_id, guardian_email, child_first_name, child_last_name}` tuples.
  """
  @callback list_existing_keys_for_programs([binary()]) :: MapSet.t()

  @doc """
  Returns true if an invite already exists for the given dedup tuple.

  Used on the single-invite path where a full `list_existing_keys_*` scan
  would transfer O(n) invites only to check one membership.
  """
  @callback invite_exists?(binary(), String.t(), String.t(), String.t()) :: boolean()
end

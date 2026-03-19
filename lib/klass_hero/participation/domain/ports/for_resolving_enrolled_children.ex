defmodule KlassHero.Participation.Domain.Ports.ForResolvingEnrolledChildren do
  @moduledoc """
  Port for resolving enrolled children from the Enrollment context.

  ## Anti-Corruption Layer

  This port defines the contract for an ACL between the Participation
  and Enrollment bounded contexts. The Participation context needs
  child IDs for enrolled children when seeding session rosters.

  Only child IDs are returned — name resolution is handled separately
  by the existing ForResolvingChildInfo port.
  """

  @doc """
  Returns child IDs with active enrollments in a program.

  Returns an empty list if no enrollments exist.
  """
  @callback list_enrolled_child_ids(program_id :: String.t()) :: [String.t()]
end

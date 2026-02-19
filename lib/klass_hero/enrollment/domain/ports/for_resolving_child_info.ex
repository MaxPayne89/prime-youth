defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingChildInfo do
  @moduledoc """
  ACL port for resolving child identity data from outside the Enrollment context.

  Enrollment needs child names to display program rosters. This port abstracts
  the source of that data (Family context) behind a simple contract.

  Returns only the fields Enrollment cares about — id and display name —
  never exposing Family domain types to the Enrollment context.
  """

  @type child_info :: %{
          id: String.t(),
          first_name: String.t(),
          last_name: String.t()
        }

  @callback get_children_by_ids(child_ids :: [String.t()]) :: [child_info()]
end

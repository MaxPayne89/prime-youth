defmodule KlassHero.Enrollment.Domain.Ports.ForResolvingParentInfo do
  @moduledoc """
  ACL port for resolving parent identity data from outside the Enrollment context.

  Enrollment needs parent user IDs to enable direct messaging from the roster.
  This port abstracts the source of that data (Family context) behind a simple contract.

  Returns only the fields Enrollment cares about — profile id and user account id —
  never exposing Family domain types to the Enrollment context.
  """

  @type parent_info :: %{
          id: String.t(),
          identity_id: String.t()
        }

  @callback get_parents_by_ids(parent_ids :: [String.t()]) :: [parent_info()]
end

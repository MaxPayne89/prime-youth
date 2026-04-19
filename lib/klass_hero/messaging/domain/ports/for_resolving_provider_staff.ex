defmodule KlassHero.Messaging.Domain.Ports.ForResolvingProviderStaff do
  @moduledoc """
  Port for querying provider-staff relationships from the Provider context.

  Distinct from `ForResolvingProgramStaff` (which queries the per-program
  `program_staff_participants` projection): this port answers the broader
  question of whether a user is an active staff member of a given provider,
  regardless of program assignment.

  Used by broadcast permission checks so that any active staff of the
  provider — not just program-assigned staff — can post follow-up messages
  in broadcasts for that provider.
  """

  @doc """
  Checks whether the given user is an active staff member of the given provider.

  Returns `true` if the user has an active `staff_member` record whose
  `provider_id` matches the given provider, `false` otherwise.
  """
  @callback active_staff_for_provider?(provider_id :: String.t(), user_id :: String.t()) ::
              boolean()
end

defmodule KlassHero.Provider.Domain.Ports.ForResolvingSessionStats do
  @moduledoc """
  Port for resolving initial session completion counts from the Participation context.

  Used exclusively during projection bootstrap. Cross-context query is acceptable
  here because it runs once on startup, not on every request.
  """

  @callback list_completed_session_counts() ::
              {:ok,
               [
                 %{
                   provider_id: String.t(),
                   program_id: String.t(),
                   program_title: String.t(),
                   sessions_completed_count: non_neg_integer()
                 }
               ]}
              | {:error, term()}
end

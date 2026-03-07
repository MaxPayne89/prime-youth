defmodule KlassHero.Family.Adapters.Driven.ACL.ChildParticipationACL do
  @moduledoc """
  ACL adapter that cleans up participation data for child deletion.

  Deletes behavioral notes and participation records directly to avoid
  a dependency cycle (Participation already depends on Family).

  Behavioral notes must be deleted before participation records because
  behavioral_notes.child_id has an ON DELETE: nothing FK constraint that
  would block child deletion.
  """

  @behaviour KlassHero.Family.Domain.Ports.ForManagingChildParticipation

  import Ecto.Query, only: [from: 2]

  alias KlassHero.Repo

  @impl true
  def delete_all_for_child(child_id) when is_binary(child_id) do
    # Trigger: behavioral_notes.child_id has ON DELETE: nothing FK constraint
    # Why: must delete behavioral notes before participation records and before child
    # Outcome: no FK violations when participation records and child are deleted
    {_notes_count, _} =
      from(n in "behavioral_notes",
        where: n.child_id == type(^child_id, :binary_id)
      )
      |> Repo.delete_all()

    {count, _} =
      from(r in "participation_records",
        where: r.child_id == type(^child_id, :binary_id)
      )
      |> Repo.delete_all()

    {:ok, count}
  end
end

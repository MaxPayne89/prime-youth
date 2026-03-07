defmodule KlassHero.Family.Domain.Ports.ForManagingChildParticipation do
  @moduledoc """
  Port for cleaning up participation data when deleting a child.

  Family needs to delete participation records and behavioral notes but
  cannot depend on the Participation context (which already depends on Family).
  This port is implemented by an ACL adapter that queries the tables directly.
  """

  @doc """
  Deletes all behavioral notes and participation records for a child.

  Behavioral notes are deleted first (they reference both child_id and
  participation_record_id). Then participation records are deleted.

  Returns counts of deleted behavioral notes and participation records.
  """
  @callback delete_all_for_child(child_id :: binary()) ::
              {:ok,
               %{participation_records: non_neg_integer(), behavioral_notes: non_neg_integer()}}
end

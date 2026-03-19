defmodule KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository.SeedBatchTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Participation.Adapters.Driven.Persistence.Repositories.ParticipationRepository

  describe "seed_batch/2" do
    test "inserts participation records for given child IDs" do
      session = insert(:program_session_schema, status: "scheduled")
      child1 = insert(:child_schema)
      child2 = insert(:child_schema)

      {:ok, count} = ParticipationRepository.seed_batch(session.id, [child1.id, child2.id])

      assert count == 2
    end

    test "skips duplicates via ON CONFLICT DO NOTHING" do
      session = insert(:program_session_schema, status: "scheduled")
      child = insert(:child_schema)

      {:ok, 1} = ParticipationRepository.seed_batch(session.id, [child.id])
      {:ok, 0} = ParticipationRepository.seed_batch(session.id, [child.id])
    end

    test "returns {:ok, 0} for empty child ID list" do
      session = insert(:program_session_schema, status: "scheduled")

      assert {:ok, 0} = ParticipationRepository.seed_batch(session.id, [])
    end
  end
end

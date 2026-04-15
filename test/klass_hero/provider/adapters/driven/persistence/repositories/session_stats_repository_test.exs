defmodule KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Provider.Adapters.Driven.Persistence.Repositories.SessionStatsRepository
  alias KlassHero.Provider.Domain.ReadModels.SessionStats

  describe "list_for_provider/1" do
    test "returns empty list when no stats exist" do
      assert [] == SessionStatsRepository.list_for_provider(Ecto.UUID.generate())
    end

    test "returns stats for the given provider ordered by count descending" do
      provider_id = Ecto.UUID.generate()

      insert(:session_stats_schema,
        provider_id: provider_id,
        program_title: "Art",
        sessions_completed_count: 3
      )

      insert(:session_stats_schema,
        provider_id: provider_id,
        program_title: "Music",
        sessions_completed_count: 7
      )

      # Different provider — should not appear
      insert(:session_stats_schema, sessions_completed_count: 10)

      result = SessionStatsRepository.list_for_provider(provider_id)

      assert [%SessionStats{program_title: "Music"}, %SessionStats{program_title: "Art"}] = result
      assert length(result) == 2
    end
  end

  describe "get_total_count/1" do
    test "returns 0 when no stats exist" do
      assert 0 == SessionStatsRepository.get_total_count(Ecto.UUID.generate())
    end

    test "returns sum of all session counts for the provider" do
      provider_id = Ecto.UUID.generate()

      insert(:session_stats_schema,
        provider_id: provider_id,
        sessions_completed_count: 3
      )

      insert(:session_stats_schema,
        provider_id: provider_id,
        sessions_completed_count: 7
      )

      assert 10 == SessionStatsRepository.get_total_count(provider_id)
    end
  end
end

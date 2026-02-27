defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepository
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Messaging.Domain.ReadModels.ConversationSummary
  alias KlassHero.Repo

  defp insert_summary(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      conversation_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      conversation_type: "direct",
      provider_id: Ecto.UUID.generate(),
      unread_count: 0,
      participant_count: 2,
      inserted_at: now,
      updated_at: now
    }

    merged = Map.merge(defaults, attrs)
    Repo.insert!(struct(ConversationSummarySchema, merged))
  end

  describe "list_for_user/2" do
    test "returns ConversationSummary DTOs for a user" do
      user_id = Ecto.UUID.generate()
      insert_summary(%{user_id: user_id, latest_message_at: ~U[2026-02-26 10:00:00Z]})

      {:ok, summaries, _has_more} = ConversationSummariesRepository.list_for_user(user_id, [])

      assert length(summaries) == 1
      assert Enum.all?(summaries, &match?(%ConversationSummary{}, &1))
    end

    test "orders by latest_message_at descending" do
      user_id = Ecto.UUID.generate()

      insert_summary(%{
        user_id: user_id,
        other_participant_name: "Older",
        latest_message_at: ~U[2026-01-01 10:00:00Z]
      })

      insert_summary(%{
        user_id: user_id,
        other_participant_name: "Newer",
        latest_message_at: ~U[2026-02-01 10:00:00Z]
      })

      {:ok, summaries, _} = ConversationSummariesRepository.list_for_user(user_id, [])

      names = Enum.map(summaries, & &1.other_participant_name)
      assert names == ["Newer", "Older"]
    end

    test "excludes archived conversations" do
      user_id = Ecto.UUID.generate()

      insert_summary(%{
        user_id: user_id,
        other_participant_name: "Active",
        archived_at: nil,
        latest_message_at: ~U[2026-02-01 10:00:00Z]
      })

      insert_summary(%{
        user_id: user_id,
        other_participant_name: "Archived",
        archived_at: ~U[2026-02-01 10:00:00Z],
        latest_message_at: ~U[2026-02-01 09:00:00Z]
      })

      {:ok, summaries, _} = ConversationSummariesRepository.list_for_user(user_id, [])

      names = Enum.map(summaries, & &1.other_participant_name)
      assert "Active" in names
      refute "Archived" in names
    end

    test "paginates with limit" do
      user_id = Ecto.UUID.generate()

      for i <- 1..5 do
        ts = DateTime.add(~U[2026-01-01 00:00:00Z], i, :second)
        insert_summary(%{user_id: user_id, latest_message_at: ts})
      end

      {:ok, summaries, has_more} =
        ConversationSummariesRepository.list_for_user(user_id, limit: 3)

      assert length(summaries) == 3
      assert has_more == true
    end

    test "does not include other users' conversations" do
      user_id = Ecto.UUID.generate()
      other_user_id = Ecto.UUID.generate()

      insert_summary(%{user_id: user_id, latest_message_at: ~U[2026-02-01 10:00:00Z]})
      insert_summary(%{user_id: other_user_id, latest_message_at: ~U[2026-02-01 10:00:00Z]})

      {:ok, summaries, _} = ConversationSummariesRepository.list_for_user(user_id, [])

      assert length(summaries) == 1
    end

    test "returns has_more false when all results fit" do
      user_id = Ecto.UUID.generate()
      insert_summary(%{user_id: user_id, latest_message_at: ~U[2026-02-01 10:00:00Z]})

      {:ok, _summaries, has_more} =
        ConversationSummariesRepository.list_for_user(user_id, limit: 10)

      assert has_more == false
    end
  end

  describe "get_total_unread_count/1" do
    test "sums unread_count across active conversations" do
      user_id = Ecto.UUID.generate()

      insert_summary(%{
        user_id: user_id,
        unread_count: 3,
        latest_message_at: ~U[2026-02-01 10:00:00Z]
      })

      insert_summary(%{
        user_id: user_id,
        unread_count: 5,
        latest_message_at: ~U[2026-02-01 11:00:00Z]
      })

      assert 8 == ConversationSummariesRepository.get_total_unread_count(user_id)
    end

    test "ignores archived conversations" do
      user_id = Ecto.UUID.generate()

      insert_summary(%{
        user_id: user_id,
        unread_count: 3,
        latest_message_at: ~U[2026-02-01 10:00:00Z]
      })

      insert_summary(%{
        user_id: user_id,
        unread_count: 5,
        archived_at: ~U[2026-02-01 10:00:00Z],
        latest_message_at: ~U[2026-02-01 09:00:00Z]
      })

      assert 3 == ConversationSummariesRepository.get_total_unread_count(user_id)
    end

    test "returns 0 when no conversations exist" do
      assert 0 == ConversationSummariesRepository.get_total_unread_count(Ecto.UUID.generate())
    end
  end
end

defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueriesTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Queries.ConversationSummaryQueries
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Repo

  describe "has_system_note_key/2" do
    test "returns true when token exists as JSONB key" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key(token)
        |> Repo.exists?()

      assert result == true
    end

    test "returns false when token does not exist as JSONB key" do
      conversation_id = Ecto.UUID.generate()

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key("[broadcast:#{Ecto.UUID.generate()}]")
        |> Repo.exists?()

      assert result == false
    end

    test "returns false when different token exists" do
      conversation_id = Ecto.UUID.generate()
      existing_token = "[broadcast:#{Ecto.UUID.generate()}]"
      missing_token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{existing_token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      result =
        ConversationSummaryQueries.base()
        |> ConversationSummaryQueries.by_conversation(conversation_id)
        |> ConversationSummaryQueries.has_system_note_key(missing_token)
        |> Repo.exists?()

      assert result == false
    end
  end

  defp insert_summary(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      conversation_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      conversation_type: "direct",
      provider_id: Ecto.UUID.generate(),
      participant_count: 2,
      unread_count: 0,
      system_notes: %{},
      inserted_at: now,
      updated_at: now
    }

    %ConversationSummarySchema{}
    |> Ecto.Changeset.change(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end

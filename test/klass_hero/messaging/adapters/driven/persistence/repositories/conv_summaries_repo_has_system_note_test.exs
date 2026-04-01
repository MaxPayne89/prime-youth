defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConvSummariesRepoHasSystemNoteTest do
  use KlassHero.DataCase, async: true

  import Ecto.Query
  import KlassHero.Factory

  alias KlassHero.AccountsFixtures
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.ConversationSummariesRepository
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.ConversationSummarySchema
  alias KlassHero.Repo

  describe "has_system_note?/2" do
    test "returns true when the token exists in system_notes" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{token => DateTime.to_iso8601(DateTime.utc_now())}
      })

      assert ConversationSummariesRepository.has_system_note?(conversation_id, token) == true
    end

    test "returns false when the token does not exist" do
      conversation_id = Ecto.UUID.generate()

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      assert ConversationSummariesRepository.has_system_note?(
               conversation_id,
               "[broadcast:#{Ecto.UUID.generate()}]"
             ) == false
    end

    test "returns false when no summary rows exist for the conversation" do
      assert ConversationSummariesRepository.has_system_note?(
               Ecto.UUID.generate(),
               "[broadcast:#{Ecto.UUID.generate()}]"
             ) == false
    end
  end

  describe "write_system_note_token/2" do
    test "writes token into system_notes JSONB" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      assert :ok = ConversationSummariesRepository.write_system_note_token(conversation_id, token)

      summary =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id,
            limit: 1
          )
        )

      assert Map.has_key?(summary.system_notes, token)
    end

    test "is idempotent — writing same token twice does not duplicate" do
      conversation_id = Ecto.UUID.generate()
      token = "[broadcast:#{Ecto.UUID.generate()}]"

      insert_summary(%{
        conversation_id: conversation_id,
        system_notes: %{}
      })

      :ok = ConversationSummariesRepository.write_system_note_token(conversation_id, token)
      :ok = ConversationSummariesRepository.write_system_note_token(conversation_id, token)

      summary =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation_id,
            limit: 1
          )
        )

      assert map_size(summary.system_notes) == 1
    end
  end

  describe "write_system_note_token/2 seed fallback" do
    test "seeds summary rows when no pre-existing summary rows exist" do
      provider = insert(:provider_profile_schema)

      conversation =
        insert(:conversation_schema, provider_id: provider.id, type: "direct")

      user = AccountsFixtures.user_fixture()

      insert(:participant_schema,
        conversation_id: conversation.id,
        user_id: user.id
      )

      token = "[broadcast:#{Ecto.UUID.generate()}]"

      assert :ok =
               ConversationSummariesRepository.write_system_note_token(conversation.id, token)

      summary =
        Repo.one(
          from(s in ConversationSummarySchema,
            where: s.conversation_id == ^conversation.id and s.user_id == ^user.id
          )
        )

      assert summary != nil
      assert Map.has_key?(summary.system_notes, token)
    end

    test "returns :ok when conversation does not exist in database" do
      assert :ok =
               ConversationSummariesRepository.write_system_note_token(
                 Ecto.UUID.generate(),
                 "[broadcast:#{Ecto.UUID.generate()}]"
               )
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

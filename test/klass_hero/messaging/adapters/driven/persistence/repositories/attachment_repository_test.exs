defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory
  import KlassHero.MessagingFixtures

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.AttachmentRepository
  alias KlassHero.Messaging.Domain.Models.Attachment

  describe "create_many/1" do
    test "inserts multiple attachments for a message" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attrs_list = [
        %{
          message_id: message.id,
          file_url: "https://s3.example.com/photo1.jpg",
          storage_path: "messaging/attachments/photo1.jpg",
          original_filename: "photo1.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 1_000_000
        },
        %{
          message_id: message.id,
          file_url: "https://s3.example.com/photo2.png",
          storage_path: "messaging/attachments/photo2.png",
          original_filename: "photo2.png",
          content_type: "image/png",
          file_size_bytes: 2_000_000
        }
      ]

      assert {:ok, attachments} = AttachmentRepository.create_many(attrs_list)
      assert length(attachments) == 2
      assert Enum.all?(attachments, &match?(%Attachment{}, &1))
      assert Enum.all?(attachments, &(&1.message_id == message.id))
    end

    test "returns ok with empty list for no attachments" do
      assert {:ok, []} = AttachmentRepository.create_many([])
    end

    test "returns error tuple for invalid foreign key instead of raising" do
      nonexistent_message_id = Ecto.UUID.generate()

      attrs_list = [
        %{
          message_id: nonexistent_message_id,
          file_url: "https://s3.example.com/photo.jpg",
          storage_path: "messaging/attachments/photo.jpg",
          original_filename: "photo.jpg",
          content_type: "image/jpeg",
          file_size_bytes: 1_000_000
        }
      ]

      assert {:error, :attachment_insert_failed} = AttachmentRepository.create_many(attrs_list)
    end
  end

  describe "list_for_message/1" do
    test "returns attachments for a message" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attachment_fixture(message.id, %{original_filename: "photo1.jpg"})
      attachment_fixture(message.id, %{original_filename: "photo2.jpg"})

      attachments = AttachmentRepository.list_for_message(message.id)
      assert length(attachments) == 2
      assert Enum.all?(attachments, &match?(%Attachment{}, &1))
    end

    test "returns empty list when no attachments exist" do
      assert [] == AttachmentRepository.list_for_message(Ecto.UUID.generate())
    end
  end

  describe "list_for_messages/1" do
    test "returns map of message_id to attachments" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      msg1 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)
      msg2 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)
      msg3 = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      attachment_fixture(msg1.id)
      attachment_fixture(msg1.id)
      attachment_fixture(msg2.id)

      result = AttachmentRepository.list_for_messages([msg1.id, msg2.id, msg3.id])

      assert length(result[msg1.id]) == 2
      assert length(result[msg2.id]) == 1
      refute Map.has_key?(result, msg3.id)
    end

    test "returns empty map for empty input" do
      assert %{} == AttachmentRepository.list_for_messages([])
    end
  end

  describe "get_storage_paths_for_conversations/1" do
    test "returns storage paths for conversation attachments" do
      conversation = insert(:conversation_schema)
      user = KlassHero.AccountsFixtures.user_fixture()
      message = insert(:message_schema, conversation_id: conversation.id, sender_id: user.id)

      a1 = attachment_fixture(message.id, %{storage_path: "messaging/attachments/path1.jpg"})
      a2 = attachment_fixture(message.id, %{storage_path: "messaging/attachments/path2.jpg"})

      assert {:ok, paths} = AttachmentRepository.get_storage_paths_for_conversations([conversation.id])
      assert length(paths) == 2
      assert a1.storage_path in paths
      assert a2.storage_path in paths
    end

    test "returns empty list when no attachments" do
      assert {:ok, []} = AttachmentRepository.get_storage_paths_for_conversations([Ecto.UUID.generate()])
    end
  end
end

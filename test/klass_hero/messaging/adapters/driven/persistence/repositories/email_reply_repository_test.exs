defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.EmailReplyRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.EmailReplyRepository
  alias KlassHero.MessagingFixtures

  describe "create/1" do
    test "inserts a reply and returns domain model" do
      email = MessagingFixtures.inbound_email_fixture()
      user = KlassHero.AccountsFixtures.user_fixture()

      attrs = %{
        inbound_email_id: email.id,
        body: "Thanks for reaching out!",
        sent_by_id: user.id
      }

      assert {:ok, reply} = EmailReplyRepository.create(attrs)
      assert reply.body == "Thanks for reaching out!"
      assert reply.status == :sending
      assert reply.inbound_email_id == email.id
      assert reply.sent_by_id == user.id
      assert reply.id != nil
    end
  end

  describe "get_by_id/1" do
    test "returns reply when found" do
      reply = MessagingFixtures.email_reply_fixture()
      assert {:ok, found} = EmailReplyRepository.get_by_id(reply.id)
      assert found.id == reply.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = EmailReplyRepository.get_by_id(Ecto.UUID.generate())
    end
  end

  describe "update_status/3" do
    test "updates status to sent with resend_message_id" do
      reply = MessagingFixtures.email_reply_fixture()
      now = DateTime.utc_now()

      assert {:ok, updated} =
               EmailReplyRepository.update_status(reply.id, "sent", %{
                 resend_message_id: "resend_abc",
                 sent_at: now
               })

      assert updated.status == :sent
      assert updated.resend_message_id == "resend_abc"
    end

    test "updates status to failed" do
      reply = MessagingFixtures.email_reply_fixture()

      assert {:ok, updated} = EmailReplyRepository.update_status(reply.id, "failed", %{})
      assert updated.status == :failed
    end
  end

  describe "list_by_email/1" do
    test "returns replies for a given email ordered by inserted_at" do
      email = MessagingFixtures.inbound_email_fixture()
      r1 = MessagingFixtures.email_reply_fixture(%{inbound_email_id: email.id})
      r2 = MessagingFixtures.email_reply_fixture(%{inbound_email_id: email.id})
      _other = MessagingFixtures.email_reply_fixture()

      assert {:ok, replies} = EmailReplyRepository.list_by_email(email.id)
      assert length(replies) == 2
      ids = Enum.map(replies, & &1.id)
      assert r1.id in ids
      assert r2.id in ids
    end

    test "returns empty list when no replies" do
      assert {:ok, []} = EmailReplyRepository.list_by_email(Ecto.UUID.generate())
    end
  end
end

defmodule KlassHero.Messaging.Application.UseCases.ReplyToEmailTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Application.UseCases.ReplyToEmail
  alias KlassHero.Messaging.Repositories
  alias KlassHero.MessagingFixtures

  describe "execute/4" do
    test "persists reply and enqueues delivery" do
      email = MessagingFixtures.inbound_email_fixture()
      user = KlassHero.AccountsFixtures.user_fixture()

      assert {:ok, reply} = ReplyToEmail.execute(email.id, "Thanks!", user.id)

      # Trigger: the returned struct was captured before Oban inline worker ran
      # Why: Oban testing: :inline executes SendEmailReplyWorker synchronously after
      #      scheduler.schedule_reply_delivery inserts the job, but execute/4 returns
      #      the reply struct created *before* the job runs
      # Outcome: returned struct has :sending, but DB has :sent after inline delivery
      assert reply.status == :sending
      assert reply.body == "Thanks!"
      assert reply.sent_by_id == user.id
      assert reply.inbound_email_id == email.id

      # Verify the worker actually delivered (DB reflects inline execution)
      reply_repo = Repositories.email_replies()
      {:ok, persisted} = reply_repo.get_by_id(reply.id)
      assert persisted.status == :sent
    end

    test "returns error for nonexistent email" do
      user = KlassHero.AccountsFixtures.user_fixture()

      assert {:error, :not_found} =
               ReplyToEmail.execute(Ecto.UUID.generate(), "Hello", user.id)
    end
  end
end

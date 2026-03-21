defmodule KlassHero.Messaging.Adapters.Driven.ObanEmailJobSchedulerTest do
  use KlassHero.DataCase, async: true
  use Oban.Testing, repo: KlassHero.Repo

  alias KlassHero.Messaging.Adapters.Driven.ObanEmailJobScheduler

  describe "schedule_content_fetch/2" do
    test "enqueues a FetchEmailContentWorker job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        email_id = Ecto.UUID.generate()

        assert {:ok, _job} =
                 ObanEmailJobScheduler.schedule_content_fetch(email_id, "resend_123")

        assert_enqueued(
          worker: KlassHero.Messaging.Workers.FetchEmailContentWorker,
          args: %{email_id: email_id, resend_id: "resend_123"}
        )
      end)
    end

    test "returns job structure with correct worker" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        email_id = Ecto.UUID.generate()

        {:ok, job} = ObanEmailJobScheduler.schedule_content_fetch(email_id, "resend_456")

        assert job.worker == "KlassHero.Messaging.Workers.FetchEmailContentWorker"
        assert job.queue == "email"
      end)
    end
  end

  describe "schedule_reply_delivery/1" do
    test "enqueues a SendEmailReplyWorker job" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        reply_id = Ecto.UUID.generate()

        assert {:ok, _job} = ObanEmailJobScheduler.schedule_reply_delivery(reply_id)

        assert_enqueued(
          worker: KlassHero.Messaging.Workers.SendEmailReplyWorker,
          args: %{reply_id: reply_id}
        )
      end)
    end

    test "returns job structure with correct queue" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        reply_id = Ecto.UUID.generate()

        {:ok, job} = ObanEmailJobScheduler.schedule_reply_delivery(reply_id)

        assert job.worker == "KlassHero.Messaging.Workers.SendEmailReplyWorker"
        assert job.queue == "email"
      end)
    end
  end
end

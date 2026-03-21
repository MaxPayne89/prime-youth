defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository
  alias KlassHero.MessagingFixtures

  describe "create/1" do
    test "inserts an inbound email and returns domain model" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()
      assert {:ok, email} = InboundEmailRepository.create(attrs)
      assert email.resend_id == attrs.resend_id
      assert email.status == :unread
    end

    test "rejects duplicate resend_id" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()
      assert {:ok, _} = InboundEmailRepository.create(attrs)
      assert {:error, _} = InboundEmailRepository.create(attrs)
    end
  end

  describe "get_by_id/1" do
    test "returns email when found" do
      email = MessagingFixtures.inbound_email_fixture()
      assert {:ok, found} = InboundEmailRepository.get_by_id(email.id)
      assert found.id == email.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = InboundEmailRepository.get_by_id(Ecto.UUID.generate())
    end
  end

  describe "get_by_resend_id/1" do
    test "returns email when found" do
      email = MessagingFixtures.inbound_email_fixture()
      assert {:ok, found} = InboundEmailRepository.get_by_resend_id(email.resend_id)
      assert found.id == email.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = InboundEmailRepository.get_by_resend_id("nonexistent")
    end
  end

  describe "list/1" do
    test "returns emails ordered by received_at desc" do
      _e1 = MessagingFixtures.inbound_email_fixture(%{received_at: ~U[2026-01-01 10:00:00Z]})
      e2 = MessagingFixtures.inbound_email_fixture(%{received_at: ~U[2026-01-02 10:00:00Z]})

      assert {:ok, emails, false} = InboundEmailRepository.list([])
      assert [first | _] = emails
      assert first.id == e2.id
    end

    test "filters by status" do
      _unread = MessagingFixtures.inbound_email_fixture()
      read = MessagingFixtures.inbound_email_fixture(%{status: "read"})

      assert {:ok, emails, false} = InboundEmailRepository.list(status: :read)
      assert length(emails) == 1
      assert hd(emails).id == read.id
    end
  end

  describe "update_status/3" do
    test "updates status to read" do
      email = MessagingFixtures.inbound_email_fixture()
      reader_id = KlassHero.AccountsFixtures.user_fixture().id

      assert {:ok, updated} =
               InboundEmailRepository.update_status(email.id, "read", %{
                 read_by_id: reader_id,
                 read_at: DateTime.utc_now()
               })

      assert updated.status == :read
      assert updated.read_by_id == reader_id
    end
  end

  describe "update_content/2" do
    test "updates body, headers, and content_status to fetched" do
      email = MessagingFixtures.inbound_email_fixture()

      attrs = %{
        body_html: "<p>Fetched content</p>",
        body_text: "Fetched content",
        headers: [%{"name" => "Message-ID", "value" => "<abc@example.com>"}],
        content_status: "fetched"
      }

      assert {:ok, updated} = InboundEmailRepository.update_content(email.id, attrs)
      assert updated.body_html == "<p>Fetched content</p>"
      assert updated.body_text == "Fetched content"
      assert updated.content_status == :fetched
    end

    test "updates content_status to failed" do
      email = MessagingFixtures.inbound_email_fixture()

      assert {:ok, updated} =
               InboundEmailRepository.update_content(email.id, %{content_status: "failed"})

      assert updated.content_status == :failed
    end

    test "returns error for nonexistent email" do
      assert {:error, :not_found} =
               InboundEmailRepository.update_content(Ecto.UUID.generate(), %{
                 content_status: "failed"
               })
    end
  end

  describe "count_by_status/1" do
    test "counts emails by status" do
      MessagingFixtures.inbound_email_fixture()
      MessagingFixtures.inbound_email_fixture()
      MessagingFixtures.inbound_email_fixture(%{status: "read"})

      assert InboundEmailRepository.count_by_status(:unread) == 2
      assert InboundEmailRepository.count_by_status(:read) == 1
    end
  end
end

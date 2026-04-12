defmodule KlassHero.Messaging.Application.Queries.ListInboundEmailsTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Repositories.InboundEmailRepository
  alias KlassHero.Messaging.Application.Queries.ListInboundEmails
  alias KlassHero.Messaging.Domain.Models.InboundEmail
  alias KlassHero.MessagingFixtures

  describe "execute/1" do
    test "returns an empty list when no emails exist" do
      assert {:ok, [], false} = ListInboundEmails.execute()
    end

    test "returns all inbound emails" do
      _email1 = MessagingFixtures.inbound_email_fixture()
      _email2 = MessagingFixtures.inbound_email_fixture()

      assert {:ok, emails, _has_more} = ListInboundEmails.execute()
      assert length(emails) == 2
      assert Enum.all?(emails, &match?(%InboundEmail{}, &1))
    end

    test "filters by status" do
      _unread = MessagingFixtures.inbound_email_fixture()

      # Create a read email by storing and then updating status
      unread2 = MessagingFixtures.inbound_email_fixture()

      InboundEmailRepository.update_status(
        unread2.id,
        "read",
        %{read_by_id: nil, read_at: DateTime.utc_now()}
      )

      assert {:ok, unread_emails, _} = ListInboundEmails.execute(status: :unread)
      assert length(unread_emails) == 1
      assert Enum.all?(unread_emails, &(&1.status == :unread))

      assert {:ok, read_emails, _} = ListInboundEmails.execute(status: :read)
      assert length(read_emails) == 1
      assert Enum.all?(read_emails, &(&1.status == :read))
    end

    test "respects limit option" do
      Enum.each(1..5, fn _ -> MessagingFixtures.inbound_email_fixture() end)

      assert {:ok, emails, has_more} = ListInboundEmails.execute(limit: 3)
      assert length(emails) == 3
      assert has_more == true
    end

    test "has_more is false when all results fit within limit" do
      MessagingFixtures.inbound_email_fixture()
      MessagingFixtures.inbound_email_fixture()

      assert {:ok, emails, has_more} = ListInboundEmails.execute(limit: 10)
      assert length(emails) == 2
      assert has_more == false
    end
  end
end

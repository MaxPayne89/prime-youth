defmodule KlassHero.Messaging.Application.UseCases.ReceiveInboundEmailTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Messaging.Application.UseCases.ReceiveInboundEmail
  alias KlassHero.Messaging.Domain.Models.InboundEmail
  alias KlassHero.MessagingFixtures

  describe "execute/1" do
    test "stores a new inbound email and returns it" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()

      assert {:ok, %InboundEmail{} = email} = ReceiveInboundEmail.execute(attrs)
      assert email.resend_id == attrs.resend_id
      assert email.from_address == attrs.from_address
      assert email.subject == attrs.subject
      assert email.status == :unread
    end

    test "returns {:ok, :duplicate} when resend_id already exists" do
      attrs = MessagingFixtures.valid_inbound_email_attrs()

      # First call stores the email
      assert {:ok, %InboundEmail{}} = ReceiveInboundEmail.execute(attrs)

      # Second call with same resend_id is a duplicate
      assert {:ok, :duplicate} = ReceiveInboundEmail.execute(attrs)
    end

    test "stores two emails with different resend_ids independently" do
      attrs1 = MessagingFixtures.valid_inbound_email_attrs()
      attrs2 = MessagingFixtures.valid_inbound_email_attrs()

      assert {:ok, email1} = ReceiveInboundEmail.execute(attrs1)
      assert {:ok, email2} = ReceiveInboundEmail.execute(attrs2)

      assert email1.resend_id != email2.resend_id
    end

    test "returns error for missing required fields" do
      invalid_attrs = %{resend_id: "some_id"}

      assert {:error, _reason} = ReceiveInboundEmail.execute(invalid_attrs)
    end
  end
end

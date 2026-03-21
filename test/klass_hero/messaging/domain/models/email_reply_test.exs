defmodule KlassHero.Messaging.Domain.Models.EmailReplyTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.EmailReply

  describe "new/1" do
    test "creates a reply with valid attrs" do
      attrs = %{
        id: Ecto.UUID.generate(),
        inbound_email_id: Ecto.UUID.generate(),
        body: "Thanks for your email!",
        sent_by_id: Ecto.UUID.generate()
      }

      assert {:ok, reply} = EmailReply.new(attrs)
      assert reply.body == "Thanks for your email!"
      assert reply.status == :sending
      assert reply.resend_message_id == nil
      assert reply.sent_at == nil
    end

    test "rejects missing required fields" do
      assert {:error, errors} = EmailReply.new(%{})
      assert "id is required" in errors
      assert "inbound_email_id is required" in errors
      assert "body is required" in errors
      assert "sent_by_id is required" in errors
    end

    test "rejects empty body" do
      attrs = %{
        id: Ecto.UUID.generate(),
        inbound_email_id: Ecto.UUID.generate(),
        body: "   ",
        sent_by_id: Ecto.UUID.generate()
      }

      assert {:error, errors} = EmailReply.new(attrs)
      assert "body must not be blank" in errors
    end
  end

  describe "mark_sent/2" do
    test "transitions from sending to sent" do
      {:ok, reply} = build_reply()

      assert {:ok, sent} = EmailReply.mark_sent(reply, "resend_abc123")
      assert sent.status == :sent
      assert sent.resend_message_id == "resend_abc123"
      assert %DateTime{} = sent.sent_at
    end

    test "is idempotent for already sent replies" do
      {:ok, reply} = build_reply()
      {:ok, sent} = EmailReply.mark_sent(reply, "resend_abc123")

      assert {:ok, ^sent} = EmailReply.mark_sent(sent, "resend_xyz")
    end
  end

  describe "mark_failed/1" do
    test "transitions from sending to failed" do
      {:ok, reply} = build_reply()

      assert {:ok, failed} = EmailReply.mark_failed(reply)
      assert failed.status == :failed
    end
  end

  defp build_reply do
    EmailReply.new(%{
      id: Ecto.UUID.generate(),
      inbound_email_id: Ecto.UUID.generate(),
      body: "Test reply",
      sent_by_id: Ecto.UUID.generate()
    })
  end
end

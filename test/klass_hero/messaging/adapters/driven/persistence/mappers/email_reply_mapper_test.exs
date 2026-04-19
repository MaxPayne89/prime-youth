defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.EmailReplyMapperTest do
  @moduledoc """
  Unit tests for EmailReplyMapper.

  Covers schema-to-domain mapping with exhaustive status parsing
  (sending/sent/failed) and creation attribute filtering.
  No database required — schemas are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.EmailReplyMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.EmailReplySchema
  alias KlassHero.Messaging.Domain.Models.EmailReply

  @inbound_email_id Ecto.UUID.generate()
  @sent_by_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      inbound_email_id: @inbound_email_id,
      body: "Thank you for your enquiry.",
      sent_by_id: @sent_by_id,
      status: "sending",
      resend_message_id: nil,
      sent_at: nil,
      inserted_at: ~U[2025-06-01 11:00:00Z],
      updated_at: ~U[2025-06-01 11:00:00Z]
    }

    struct!(EmailReplySchema, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "converts all fields from schema to domain struct" do
      schema = valid_schema()

      reply = EmailReplyMapper.to_domain(schema)

      assert %EmailReply{} = reply
      assert reply.id == schema.id
      assert reply.inbound_email_id == @inbound_email_id
      assert reply.body == "Thank you for your enquiry."
      assert reply.sent_by_id == @sent_by_id
      assert reply.resend_message_id == nil
      assert reply.sent_at == nil
      assert reply.inserted_at == ~U[2025-06-01 11:00:00Z]
      assert reply.updated_at == ~U[2025-06-01 11:00:00Z]
    end

    test "parses status 'sending' to :sending atom" do
      schema = valid_schema(%{status: "sending"})

      assert EmailReplyMapper.to_domain(schema).status == :sending
    end

    test "parses status 'sent' to :sent atom" do
      schema = valid_schema(%{status: "sent"})

      assert EmailReplyMapper.to_domain(schema).status == :sent
    end

    test "parses status 'failed' to :failed atom" do
      schema = valid_schema(%{status: "failed"})

      assert EmailReplyMapper.to_domain(schema).status == :failed
    end

    test "preserves resend_message_id and sent_at when set" do
      sent_at = ~U[2025-06-01 11:30:00Z]
      schema = valid_schema(%{status: "sent", resend_message_id: "re_msg999", sent_at: sent_at})

      reply = EmailReplyMapper.to_domain(schema)

      assert reply.resend_message_id == "re_msg999"
      assert reply.sent_at == sent_at
    end
  end

  describe "to_create_attrs/1" do
    test "takes only permitted keys" do
      attrs = %{
        inbound_email_id: @inbound_email_id,
        body: "Hello",
        sent_by_id: @sent_by_id,
        status: "sending",
        resend_message_id: nil,
        sent_at: nil,
        extra_field: "ignored"
      }

      result = EmailReplyMapper.to_create_attrs(attrs)

      assert Map.has_key?(result, :inbound_email_id)
      assert Map.has_key?(result, :body)
      assert Map.has_key?(result, :sent_by_id)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :resend_message_id)
      assert Map.has_key?(result, :sent_at)
      refute Map.has_key?(result, :extra_field)
    end

    test "does not include id even if provided" do
      attrs = %{id: Ecto.UUID.generate(), inbound_email_id: @inbound_email_id, body: "Hi"}

      result = EmailReplyMapper.to_create_attrs(attrs)

      refute Map.has_key?(result, :id)
    end

    test "returns empty map when no permitted keys given" do
      result = EmailReplyMapper.to_create_attrs(%{foo: "bar"})

      assert result == %{}
    end
  end
end

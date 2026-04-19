defmodule KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.InboundEmailMapperTest do
  @moduledoc """
  Unit tests for InboundEmailMapper.

  Focuses on exhaustive status/content_status parsing (pattern-matched, not
  String.to_existing_atom) and default injection in to_create_attrs/1.
  No database required — schemas are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Adapters.Driven.Persistence.Mappers.InboundEmailMapper
  alias KlassHero.Messaging.Adapters.Driven.Persistence.Schemas.InboundEmailSchema
  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @resend_id "resend_abc123"

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      resend_id: @resend_id,
      from_address: "sender@example.com",
      from_name: "Test Sender",
      to_addresses: ["inbox@klass.hero"],
      cc_addresses: [],
      subject: "Booking Inquiry",
      body_html: "<p>Hello</p>",
      body_text: "Hello",
      headers: [],
      message_id: "<msg123@example.com>",
      status: "unread",
      content_status: "pending",
      read_by_id: nil,
      read_at: nil,
      received_at: ~U[2025-05-01 08:00:00.000000Z],
      inserted_at: ~U[2025-05-01 08:00:00Z],
      updated_at: ~U[2025-05-01 08:00:00Z]
    }

    struct!(InboundEmailSchema, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "converts all fields from schema to domain struct" do
      schema = valid_schema()

      email = InboundEmailMapper.to_domain(schema)

      assert %InboundEmail{} = email
      assert email.id == schema.id
      assert email.resend_id == @resend_id
      assert email.from_address == "sender@example.com"
      assert email.from_name == "Test Sender"
      assert email.to_addresses == ["inbox@klass.hero"]
      assert email.cc_addresses == []
      assert email.subject == "Booking Inquiry"
      assert email.body_html == "<p>Hello</p>"
      assert email.body_text == "Hello"
      assert email.message_id == "<msg123@example.com>"
      assert email.read_by_id == nil
      assert email.read_at == nil
    end

    test "parses status 'unread' to :unread atom" do
      schema = valid_schema(%{status: "unread"})

      assert InboundEmailMapper.to_domain(schema).status == :unread
    end

    test "parses status 'read' to :read atom" do
      schema = valid_schema(%{status: "read"})

      assert InboundEmailMapper.to_domain(schema).status == :read
    end

    test "parses status 'archived' to :archived atom" do
      schema = valid_schema(%{status: "archived"})

      assert InboundEmailMapper.to_domain(schema).status == :archived
    end

    test "parses content_status 'pending' to :pending atom" do
      schema = valid_schema(%{content_status: "pending"})

      assert InboundEmailMapper.to_domain(schema).content_status == :pending
    end

    test "parses content_status 'fetched' to :fetched atom" do
      schema = valid_schema(%{content_status: "fetched"})

      assert InboundEmailMapper.to_domain(schema).content_status == :fetched
    end

    test "parses content_status 'failed' to :failed atom" do
      schema = valid_schema(%{content_status: "failed"})

      assert InboundEmailMapper.to_domain(schema).content_status == :failed
    end

    test "preserves read_by_id and read_at when set" do
      user_id = Ecto.UUID.generate()
      read_at = ~U[2025-05-02 09:30:00.000000Z]
      schema = valid_schema(%{status: "read", read_by_id: user_id, read_at: read_at})

      email = InboundEmailMapper.to_domain(schema)

      assert email.read_by_id == user_id
      assert email.read_at == read_at
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      email = InboundEmailMapper.to_domain(schema)

      assert email.received_at == ~U[2025-05-01 08:00:00.000000Z]
      assert email.inserted_at == ~U[2025-05-01 08:00:00Z]
      assert email.updated_at == ~U[2025-05-01 08:00:00Z]
    end
  end

  describe "to_create_attrs/1" do
    test "takes only permitted keys" do
      attrs = %{
        resend_id: @resend_id,
        from_address: "sender@example.com",
        to_addresses: ["inbox@klass.hero"],
        subject: "Hello",
        received_at: ~U[2025-05-01 08:00:00.000000Z],
        extra_field: "ignored",
        id: "should-be-ignored"
      }

      result = InboundEmailMapper.to_create_attrs(attrs)

      assert Map.has_key?(result, :resend_id)
      assert Map.has_key?(result, :from_address)
      assert Map.has_key?(result, :to_addresses)
      assert Map.has_key?(result, :subject)
      assert Map.has_key?(result, :received_at)
      refute Map.has_key?(result, :extra_field)
      refute Map.has_key?(result, :id)
    end

    test "defaults status to 'unread' when not provided" do
      attrs = %{resend_id: @resend_id, from_address: "sender@example.com"}

      result = InboundEmailMapper.to_create_attrs(attrs)

      assert result.status == "unread"
    end

    test "keeps explicitly provided status" do
      attrs = %{resend_id: @resend_id, status: "archived"}

      result = InboundEmailMapper.to_create_attrs(attrs)

      assert result.status == "archived"
    end

    test "defaults content_status to 'pending' when not provided" do
      attrs = %{resend_id: @resend_id}

      result = InboundEmailMapper.to_create_attrs(attrs)

      assert result.content_status == "pending"
    end

    test "keeps explicitly provided content_status" do
      attrs = %{resend_id: @resend_id, content_status: "fetched"}

      result = InboundEmailMapper.to_create_attrs(attrs)

      assert result.content_status == "fetched"
    end
  end
end

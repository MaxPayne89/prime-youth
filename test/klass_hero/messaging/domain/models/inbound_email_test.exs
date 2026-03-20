defmodule KlassHero.Messaging.Domain.Models.InboundEmailTest do
  use ExUnit.Case, async: true

  alias KlassHero.Messaging.Domain.Models.InboundEmail

  @valid_attrs %{
    id: Ecto.UUID.generate(),
    resend_id: "resend_abc123",
    from_address: "sender@example.com",
    to_addresses: ["hello@klasshero.com"],
    subject: "Test Subject",
    received_at: DateTime.utc_now()
  }

  describe "new/1" do
    test "creates an inbound email with valid attributes" do
      assert {:ok, email} = InboundEmail.new(@valid_attrs)
      assert email.from_address == "sender@example.com"
      assert email.status == :unread
    end

    test "returns error for missing required fields" do
      assert {:error, errors} = InboundEmail.new(%{})
      assert is_list(errors)
      refute Enum.empty?(errors)
    end

    test "returns error for invalid status" do
      attrs = Map.put(@valid_attrs, :status, :invalid)
      assert {:error, _} = InboundEmail.new(attrs)
    end
  end

  describe "mark_read/2" do
    test "transitions from unread to read" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      reader_id = Ecto.UUID.generate()
      {:ok, read_email} = InboundEmail.mark_read(email, reader_id)
      assert read_email.status == :read
      assert read_email.read_by_id == reader_id
      assert read_email.read_at != nil
    end

    test "is idempotent when already read" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      reader_id = Ecto.UUID.generate()
      {:ok, read_email} = InboundEmail.mark_read(email, reader_id)
      {:ok, same_email} = InboundEmail.mark_read(read_email, Ecto.UUID.generate())
      assert same_email.read_by_id == reader_id
    end

    test "does not mark archived email as read" do
      {:ok, email} = InboundEmail.new(Map.put(@valid_attrs, :status, :archived))
      {:ok, same} = InboundEmail.mark_read(email, Ecto.UUID.generate())
      assert same.status == :archived
    end
  end

  describe "archive/1" do
    test "transitions to archived" do
      {:ok, email} = InboundEmail.new(@valid_attrs)
      {:ok, archived} = InboundEmail.archive(email)
      assert archived.status == :archived
    end
  end

  describe "mark_unread/1" do
    test "transitions from read to unread" do
      {:ok, email} = InboundEmail.new(Map.put(@valid_attrs, :status, :read))
      {:ok, unread} = InboundEmail.mark_unread(email)
      assert unread.status == :unread
      assert unread.read_by_id == nil
      assert unread.read_at == nil
    end
  end
end

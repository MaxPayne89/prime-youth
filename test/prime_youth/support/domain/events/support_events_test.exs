defmodule KlassHero.Support.Domain.Events.SupportEventsTest do
  use ExUnit.Case, async: true

  alias KlassHero.Support.Domain.Events.SupportEvents
  alias KlassHero.Support.Domain.Models.ContactRequest

  # Helper to create a valid contact request with only required overrides
  defp valid_contact_request(overrides \\ []) do
    defaults = [
      id: "contact_123",
      name: "John Doe",
      email: "john@example.com",
      subject: "general",
      message: "Hello, I have a question.",
      submitted_at: ~U[2024-03-15 10:30:00Z]
    ]

    struct(ContactRequest, Keyword.merge(defaults, overrides))
  end

  describe "contact_request_submitted/3 validation" do
    test "raises when contact_request.id is nil" do
      contact_request = valid_contact_request(id: nil)

      assert_raise ArgumentError,
                   "ContactRequest.id cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.id is empty string" do
      contact_request = valid_contact_request(id: "")

      assert_raise ArgumentError,
                   "ContactRequest.id cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.name is nil" do
      contact_request = valid_contact_request(name: nil)

      assert_raise ArgumentError,
                   "ContactRequest.name cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.name is empty string" do
      contact_request = valid_contact_request(name: "")

      assert_raise ArgumentError,
                   "ContactRequest.name cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.email is nil" do
      contact_request = valid_contact_request(email: nil)

      assert_raise ArgumentError,
                   "ContactRequest.email cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.email is empty string" do
      contact_request = valid_contact_request(email: "")

      assert_raise ArgumentError,
                   "ContactRequest.email cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.subject is nil" do
      contact_request = valid_contact_request(subject: nil)

      assert_raise ArgumentError,
                   "ContactRequest.subject cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "raises when contact_request.subject is empty string" do
      contact_request = valid_contact_request(subject: "")

      assert_raise ArgumentError,
                   "ContactRequest.subject cannot be nil or empty",
                   fn -> SupportEvents.contact_request_submitted(contact_request) end
    end

    test "succeeds with valid contact_request" do
      contact_request = valid_contact_request()

      event = SupportEvents.contact_request_submitted(contact_request)

      assert event.event_type == :contact_request_submitted
      assert event.aggregate_id == "contact_123"
      assert event.aggregate_type == :contact_request
      assert event.payload.name == "John Doe"
      assert event.payload.email == "john@example.com"
      assert event.payload.subject == "general"
    end

    test "succeeds with valid contact_request and custom payload" do
      contact_request = valid_contact_request()

      event = SupportEvents.contact_request_submitted(contact_request, %{user_id: 456})

      assert event.payload.user_id == 456
    end
  end
end

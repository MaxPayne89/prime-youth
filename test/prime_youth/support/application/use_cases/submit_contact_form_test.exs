defmodule PrimeYouth.Support.Application.UseCases.SubmitContactFormTest do
  use ExUnit.Case, async: true

  import PrimeYouth.EventTestHelper

  alias PrimeYouth.Support.Application.UseCases.SubmitContactForm
  alias PrimeYouth.Support.Domain.Models.ContactRequest

  setup do
    setup_test_events()
    :ok
  end

  describe "execute/1" do
    test "successfully submits valid contact form" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "This is a test message with enough characters."
      }

      assert {:ok, %ContactRequest{} = contact} = SubmitContactForm.execute(params)
      assert contact.name == "John Doe"
      assert contact.email == "john@example.com"
      assert contact.subject == "general"
      assert contact.message == "This is a test message with enough characters."
      assert String.starts_with?(contact.id, "contact_")
      assert %DateTime{} = contact.submitted_at

      # Verify event published
      assert_event_published(:contact_request_submitted)

      assert_event_published(:contact_request_submitted, %{
        name: "John Doe",
        email: "john@example.com",
        subject: "general"
      })
    end

    test "generates unique IDs for each submission" do
      params = %{
        "name" => "Jane Smith",
        "email" => "jane@example.com",
        "subject" => "program",
        "message" => "I am interested in the art program for my child."
      }

      assert {:ok, contact1} = SubmitContactForm.execute(params)
      assert {:ok, contact2} = SubmitContactForm.execute(params)
      assert contact1.id != contact2.id
      assert String.starts_with?(contact1.id, "contact_")
      assert String.starts_with?(contact2.id, "contact_")
    end

    test "preserves all subject options" do
      base_params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "message" => "This is a test message with enough characters."
      }

      subjects = ["general", "program", "booking", "instructor", "technical", "other"]

      for subject <- subjects do
        params = Map.put(base_params, "subject", subject)
        assert {:ok, contact} = SubmitContactForm.execute(params)
        assert contact.subject == subject
      end
    end

    test "returns validation error for missing name" do
      params = %{
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "can't be blank" in errors_on(changeset).name
      # No events should be published on validation error
      assert_no_events_published()
    end

    test "returns validation error for short name" do
      params = %{
        "name" => "J",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "should be at least 2 character(s)" in errors_on(changeset).name
      # No events should be published on validation error
      assert_no_events_published()
    end

    test "returns validation error for invalid email" do
      params = %{
        "name" => "John Doe",
        "email" => "invalid-email",
        "subject" => "general",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "must be a valid email address" in errors_on(changeset).email
      # No events should be published on validation error
      assert_no_events_published()
    end

    test "returns validation error for missing email" do
      params = %{
        "name" => "John Doe",
        "subject" => "general",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns validation error for short message" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "Short"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "should be at least 10 character(s)" in errors_on(changeset).message
    end

    test "returns validation error for long message" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => String.duplicate("a", 1001)
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "should be at most 1000 character(s)" in errors_on(changeset).message
    end

    test "returns validation error for missing message" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "can't be blank" in errors_on(changeset).message
    end

    test "returns validation error for invalid subject" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "invalid",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "is invalid" in errors_on(changeset).subject
    end

    test "returns validation error for missing subject" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "message" => "This is a test message."
      }

      assert {:error, %Ecto.Changeset{} = changeset} = SubmitContactForm.execute(params)
      assert "can't be blank" in errors_on(changeset).subject
    end

    test "accepts maximum length name (100 characters)" do
      params = %{
        "name" => String.duplicate("a", 100),
        "email" => "john@example.com",
        "subject" => "general",
        "message" => "This is a test message with enough characters."
      }

      assert {:ok, %ContactRequest{}} = SubmitContactForm.execute(params)
    end

    test "accepts maximum length message (1000 characters)" do
      params = %{
        "name" => "John Doe",
        "email" => "john@example.com",
        "subject" => "general",
        "message" => String.duplicate("a", 1000)
      }

      assert {:ok, %ContactRequest{}} = SubmitContactForm.execute(params)
    end
  end

  describe "execute/1 - event publishing" do
    test "publishes contact_request_submitted event with correct payload" do
      params = %{
        "name" => "Jane Smith",
        "email" => "jane@example.com",
        "subject" => "program",
        "message" => "I am interested in the art program for my child."
      }

      assert {:ok, contact} = SubmitContactForm.execute(params)

      # Verify event was published
      event = assert_event_published(:contact_request_submitted)
      assert event.payload.name == "Jane Smith"
      assert event.payload.email == "jane@example.com"
      assert event.payload.subject == "program"
      assert event.aggregate_id == contact.id
      assert event.aggregate_type == :contact_request
    end

    test "publishes events for all subject types" do
      base_params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "message" => "This is a test message with enough characters."
      }

      subjects = ["general", "program", "booking", "instructor", "technical", "other"]

      for subject <- subjects do
        clear_events()
        params = Map.put(base_params, "subject", subject)

        assert {:ok, _contact} = SubmitContactForm.execute(params)

        # Verify event published with correct subject
        event = assert_event_published(:contact_request_submitted)
        assert event.payload.subject == subject
      end
    end

    test "does not publish events when validation fails" do
      invalid_params = %{
        "name" => "J",
        # Too short
        "email" => "invalid-email",
        "subject" => "general",
        "message" => "Short"
        # Too short
      }

      assert {:error, %Ecto.Changeset{}} = SubmitContactForm.execute(invalid_params)
      assert_no_events_published()
    end

    test "publishes distinct events for multiple submissions" do
      params1 = %{
        "name" => "Alice",
        "email" => "alice@example.com",
        "subject" => "general",
        "message" => "Message from Alice with enough characters to pass validation."
      }

      params2 = %{
        "name" => "Bob",
        "email" => "bob@example.com",
        "subject" => "program",
        "message" => "Message from Bob with enough characters to pass validation."
      }

      {:ok, contact1} = SubmitContactForm.execute(params1)
      {:ok, contact2} = SubmitContactForm.execute(params2)

      # Verify both events published
      assert_event_count(2)

      events = get_published_events()
      assert Enum.all?(events, &(&1.event_type == :contact_request_submitted))

      # Verify each event has correct data
      alice_event = Enum.find(events, &(&1.payload.email == "alice@example.com"))
      bob_event = Enum.find(events, &(&1.payload.email == "bob@example.com"))

      assert alice_event.payload.name == "Alice"
      assert alice_event.aggregate_id == contact1.id

      assert bob_event.payload.name == "Bob"
      assert bob_event.aggregate_id == contact2.id
    end

    test "publishes exactly one event per submission" do
      params = %{
        "name" => "Test User",
        "email" => "test@example.com",
        "subject" => "general",
        "message" => "This is a test message with enough characters."
      }

      SubmitContactForm.execute(params)
      assert_event_count(1)

      clear_events()

      SubmitContactForm.execute(params)
      assert_event_count(1)
    end

    test "does not include message in event payload" do
      params = %{
        "name" => "Privacy Test",
        "email" => "privacy@example.com",
        "subject" => "general",
        "message" => "This message should not be in the event payload."
      }

      SubmitContactForm.execute(params)

      event = assert_event_published(:contact_request_submitted)
      # Verify message is not in payload (privacy consideration)
      refute Map.has_key?(event.payload, :message)
    end
  end

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

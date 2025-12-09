defmodule PrimeYouth.Support.Application.UseCases.SubmitContactFormTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.Support.Application.UseCases.SubmitContactForm
  alias PrimeYouth.Support.Domain.Models.ContactRequest

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

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

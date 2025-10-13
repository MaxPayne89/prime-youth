defmodule PrimeYouth.Auth.Domain.UserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PrimeYouth.Auth.Domain.User

  describe "new/1" do
    test "creates a valid user with all required fields" do
      attrs = %{
        email: "test@example.com",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, user} = User.new(attrs)
      assert user.email == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.confirmed_at == nil
    end

    test "downcases email addresses" do
      attrs = %{
        email: "Test@EXAMPLE.COM",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, user} = User.new(attrs)
      assert user.email == "test@example.com"
    end

    test "trims whitespace from email" do
      attrs = %{
        email: "  test@example.com  ",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, user} = User.new(attrs)
      assert user.email == "test@example.com"
    end

    test "trims whitespace from names" do
      attrs = %{
        email: "test@example.com",
        first_name: "  John  ",
        last_name: "  Doe  "
      }

      assert {:ok, user} = User.new(attrs)
      assert user.first_name == "John"
      assert user.last_name == "Doe"
    end

    test "returns error when email is nil" do
      attrs = %{
        email: nil,
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, :email_required} = User.new(attrs)
    end

    test "returns error when email is empty" do
      attrs = %{
        email: "",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, :email_required} = User.new(attrs)
    end

    test "returns error when email format is invalid" do
      invalid_emails = [
        "notanemail",
        "@example.com",
        "test@",
        "test @example.com",
        "test@example",
        123
      ]

      for invalid_email <- invalid_emails do
        attrs = %{
          email: invalid_email,
          first_name: "John",
          last_name: "Doe"
        }

        assert {:error, _} = User.new(attrs)
      end
    end

    test "returns error when email is too long" do
      long_email = String.duplicate("a", 150) <> "@example.com"

      attrs = %{
        email: long_email,
        first_name: "John",
        last_name: "Doe"
      }

      assert {:error, :email_too_long} = User.new(attrs)
    end

    test "returns error when first_name is nil" do
      attrs = %{
        email: "test@example.com",
        first_name: nil,
        last_name: "Doe"
      }

      assert {:error, :first_name_required} = User.new(attrs)
    end

    test "returns error when first_name is empty" do
      attrs = %{
        email: "test@example.com",
        first_name: "",
        last_name: "Doe"
      }

      assert {:error, :first_name_required} = User.new(attrs)
    end

    test "returns error when last_name is nil" do
      attrs = %{
        email: "test@example.com",
        first_name: "John",
        last_name: nil
      }

      assert {:error, :last_name_required} = User.new(attrs)
    end

    test "returns error when last_name is empty" do
      attrs = %{
        email: "test@example.com",
        first_name: "John",
        last_name: ""
      }

      assert {:error, :last_name_required} = User.new(attrs)
    end

    test "returns error when name is too long" do
      long_name = String.duplicate("a", 101)

      attrs = %{
        email: "test@example.com",
        first_name: long_name,
        last_name: "Doe"
      }

      assert {:error, :name_too_long} = User.new(attrs)
    end
  end

  describe "confirm/2" do
    test "sets confirmed_at timestamp" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})
      confirmed_at = DateTime.utc_now()

      confirmed_user = User.confirm(user, confirmed_at)

      assert confirmed_user.confirmed_at == confirmed_at
    end
  end

  describe "update_email/2" do
    test "updates email with valid new email" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})
      user = User.confirm(user, DateTime.utc_now())

      assert {:ok, updated_user} = User.update_email(user, "newemail@example.com")
      assert updated_user.email == "newemail@example.com"
      assert updated_user.confirmed_at == nil
    end

    test "returns error when new email is invalid" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})

      assert {:error, _} = User.update_email(user, "invalid")
    end

    test "downcases new email" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})

      assert {:ok, updated_user} = User.update_email(user, "NewEmail@EXAMPLE.COM")
      assert updated_user.email == "newemail@example.com"
    end
  end

  describe "confirmed?/1" do
    test "returns false when user is not confirmed" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})

      refute User.confirmed?(user)
    end

    test "returns true when user is confirmed" do
      {:ok, user} = User.new(%{email: "test@example.com", first_name: "John", last_name: "Doe"})
      user = User.confirm(user, DateTime.utc_now())

      assert User.confirmed?(user)
    end
  end

  # Property-based tests
  describe "property-based email validation" do
    property "accepts valid email format" do
      check all(
              local <- string(:alphanumeric, min_length: 1, max_length: 64),
              domain <- string(:alphanumeric, min_length: 1, max_length: 63),
              tld <- string(:alphanumeric, min_length: 2, max_length: 10)
            ) do
        email = "#{local}@#{domain}.#{tld}"

        if String.length(email) <= 160 do
          assert {:ok, validated} = User.validate_email(email)
          assert validated == String.downcase(email)
        end
      end
    end

    property "rejects emails without @ symbol" do
      check all(str <- string(:alphanumeric, min_length: 1, max_length: 50)) do
        if not String.contains?(str, "@") do
          assert {:error, _} = User.validate_email(str)
        end
      end
    end
  end

  describe "property-based name validation" do
    property "accepts names within length limits" do
      check all(name <- string(:alphanumeric, min_length: 1, max_length: 100)) do
        assert {:ok, _} = User.validate_name(name, :first_name)
      end
    end

    property "rejects names over 100 characters" do
      check all(name <- string(:alphanumeric, min_length: 101, max_length: 200)) do
        assert {:error, :name_too_long} = User.validate_name(name, :first_name)
      end
    end
  end
end

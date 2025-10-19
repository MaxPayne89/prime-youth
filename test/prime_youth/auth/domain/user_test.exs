defmodule PrimeYouth.Auth.Domain.Models.UserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Funx.Errors.ValidationError
  alias Funx.Monad.Either
  alias PrimeYouth.Auth.Domain.Models.User

  describe "make/2 (Either-based constructor)" do
    test "returns Right with valid data" do
      assert %Either.Right{right: user} =
               User.make("test@example.com", first_name: "John", last_name: "Doe")

      assert user.email == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.confirmed_at == nil
    end

    test "returns Left when email is invalid" do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("", first_name: "John", last_name: "Doe")

      assert "Email is required" in errors
    end

    test "returns Left when email has invalid format" do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("notanemail", first_name: "John", last_name: "Doe")

      assert Enum.any?(errors, &String.contains?(&1, "invalid format"))
    end

    test "returns Left when first name is missing" do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("test@example.com", first_name: "", last_name: "Doe")

      assert "First name is required" in errors
    end

    test "returns Left when last name is missing" do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("test@example.com", first_name: "John", last_name: "")

      assert "Last name is required" in errors
    end

    test "accumulates multiple validation errors" do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("", first_name: "", last_name: "")

      assert "Email is required" in errors
      assert "First name is required" in errors
      assert "Last name is required" in errors
    end

    test "normalizes email by downcasing" do
      assert %Either.Right{right: user} =
               User.make("Test@EXAMPLE.COM", first_name: "John", last_name: "Doe")

      assert user.email == "test@example.com"
    end

    test "normalizes email by trimming whitespace" do
      assert %Either.Right{right: user} =
               User.make("  test@example.com  ", first_name: "John", last_name: "Doe")

      assert user.email == "test@example.com"
    end

    test "normalizes names by trimming whitespace" do
      assert %Either.Right{right: user} =
               User.make("test@example.com", first_name: "  John  ", last_name: "  Doe  ")

      assert user.first_name == "John"
      assert user.last_name == "Doe"
    end

    test "returns Left when email is too long" do
      long_email = String.duplicate("a", 150) <> "@example.com"

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make(long_email, first_name: "John", last_name: "Doe")

      assert Enum.any?(errors, &String.contains?(&1, "too long"))
    end

    test "returns Left when first name is too long" do
      long_name = String.duplicate("a", 101)

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("test@example.com", first_name: long_name, last_name: "Doe")

      assert Enum.any?(errors, &String.contains?(&1, "too long"))
    end

    test "returns Left when last name is too long" do
      long_name = String.duplicate("a", 101)

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.make("test@example.com", first_name: "John", last_name: long_name)

      assert Enum.any?(errors, &String.contains?(&1, "too long"))
    end
  end

  describe "change/2 (Either-based change)" do
    setup do
      {:ok,
       user: unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))}
    end

    test "returns Right when changing to valid data", %{user: user} do
      assert %Either.Right{right: updated_user} =
               User.change(user, %{first_name: "Jane"})

      assert updated_user.first_name == "Jane"
      assert updated_user.email == "test@example.com"
    end

    test "returns Left when changing to invalid email", %{user: user} do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.change(user, %{email: "invalid"})

      assert Enum.any?(errors, &String.contains?(&1, "invalid format"))
    end

    test "returns Left when changing to empty first name", %{user: user} do
      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.change(user, %{first_name: ""})

      assert "First name is required" in errors
    end

    test "protects ID from modification", %{user: user} do
      user_with_id = %{user | id: 123}

      assert %Either.Right{right: updated_user} =
               User.change(user_with_id, %{id: 999, first_name: "Jane"})

      assert updated_user.id == 123
      assert updated_user.first_name == "Jane"
    end

    test "normalizes email before validation", %{user: user} do
      assert %Either.Right{right: updated_user} =
               User.change(user, %{email: "  NEW@EXAMPLE.COM  "})

      assert updated_user.email == "new@example.com"
    end

    test "normalizes names before validation", %{user: user} do
      assert %Either.Right{right: updated_user} =
               User.change(user, %{first_name: "  Jane  ", last_name: "  Smith  "})

      assert updated_user.first_name == "Jane"
      assert updated_user.last_name == "Smith"
    end
  end

  describe "validate/1 (comprehensive validation)" do
    test "returns Right with valid user" do
      user_result = User.make("test@example.com", first_name: "John", last_name: "Doe")
      user = unwrap_right(user_result)

      assert %Either.Right{right: validated_user} = User.validate(user)
      assert validated_user.email == "test@example.com"
      assert validated_user.first_name == "John"
      assert validated_user.last_name == "Doe"
    end
  end

  describe "ensure_valid_email/1" do
    test "returns Right when email is valid" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_email(user)
      assert validated_user.email == "test@example.com"
    end
  end

  describe "ensure_valid_first_name/1" do
    test "returns Right when first name is valid" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_first_name(user)
      assert validated_user.first_name == "John"
    end
  end

  describe "ensure_valid_last_name/1" do
    test "returns Right when last name is valid" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_last_name(user)
      assert validated_user.last_name == "Doe"
    end
  end

  describe "confirm/2" do
    test "returns Right with valid DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      confirmed_at = DateTime.utc_now()

      assert %Either.Right{right: confirmed_user} = User.confirm(user, confirmed_at)
      assert confirmed_user.confirmed_at == confirmed_at
    end

    test "returns Left when timestamp is invalid" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.confirm(user, "invalid_timestamp")

      assert Enum.any?(errors, &String.contains?(&1, "must be a valid DateTime"))
    end
  end

  describe "authenticate/2" do
    test "returns Right with valid DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      authenticated_at = DateTime.utc_now()

      assert %Either.Right{right: authenticated_user} = User.authenticate(user, authenticated_at)
      assert authenticated_user.authenticated_at == authenticated_at
    end

    test "returns Left when timestamp is invalid" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.authenticate(user, "invalid_timestamp")

      assert Enum.any?(errors, &String.contains?(&1, "must be a valid DateTime"))
    end

    test "allows nil for authenticated_at (not yet authenticated)" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: authenticated_user} = User.authenticate(user, nil)
      assert authenticated_user.authenticated_at == nil
    end
  end

  describe "update_email/2" do
    test "returns Right with valid new email" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      confirmed_user = unwrap_right(User.confirm(user, DateTime.utc_now()))

      assert %Either.Right{right: updated_user} =
               User.update_email(confirmed_user, "newemail@example.com")

      assert updated_user.email == "newemail@example.com"
      assert updated_user.confirmed_at == nil
    end

    test "returns Left with invalid email" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.update_email(user, "invalid")

      assert Enum.any?(errors, &String.contains?(&1, "invalid format"))
    end

    test "normalizes new email before validation" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: updated_user} =
               User.update_email(user, "  NewEmail@EXAMPLE.COM  ")

      assert updated_user.email == "newemail@example.com"
    end

    test "resets confirmed_at when changing email" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      confirmed_user = unwrap_right(User.confirm(user, DateTime.utc_now()))

      assert %Either.Right{right: updated_user} =
               User.update_email(confirmed_user, "newemail@example.com")

      assert updated_user.confirmed_at == nil
    end
  end

  describe "confirmed?/1" do
    test "returns false when user is not confirmed" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      refute User.confirmed?(user)
    end

    test "returns true when user is confirmed" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      confirmed_user = unwrap_right(User.confirm(user, DateTime.utc_now()))

      assert User.confirmed?(confirmed_user)
    end
  end

  describe "ensure_valid_confirmed_at/1" do
    test "returns Right when confirmed_at is valid DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      confirmed_user = unwrap_right(User.confirm(user, DateTime.utc_now()))

      assert %Either.Right{right: validated_user} = User.ensure_valid_confirmed_at(confirmed_user)
      assert validated_user.confirmed_at != nil
    end

    test "returns Right when confirmed_at is nil (unconfirmed user)" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_confirmed_at(user)
      assert validated_user.confirmed_at == nil
    end

    test "returns Left when confirmed_at is not a DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      invalid_user = %{user | confirmed_at: "2024-01-01"}

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.ensure_valid_confirmed_at(invalid_user)

      assert Enum.any?(errors, &String.contains?(&1, "must be a valid DateTime"))
    end
  end

  describe "ensure_valid_authenticated_at/1" do
    test "returns Right when authenticated_at is valid DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      authenticated_user = unwrap_right(User.authenticate(user, DateTime.utc_now()))

      assert %Either.Right{right: validated_user} =
               User.ensure_valid_authenticated_at(authenticated_user)

      assert validated_user.authenticated_at != nil
    end

    test "returns Right when authenticated_at is nil" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_authenticated_at(user)
      assert validated_user.authenticated_at == nil
    end

    test "returns Left when authenticated_at is not a DateTime" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      invalid_user = %{user | authenticated_at: "2024-01-01"}

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.ensure_valid_authenticated_at(invalid_user)

      assert Enum.any?(errors, &String.contains?(&1, "must be a valid DateTime or nil"))
    end
  end

  describe "ensure_valid_hashed_password/1" do
    test "returns Right when hashed_password is nil (OAuth users)" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))

      assert %Either.Right{right: validated_user} = User.ensure_valid_hashed_password(user)
      assert validated_user.hashed_password == nil
    end

    test "returns Right when hashed_password is a non-empty string" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      user_with_password = unwrap_right(User.change(user, %{hashed_password: "hashed_pw_123"}))

      assert %Either.Right{right: validated_user} =
               User.ensure_valid_hashed_password(user_with_password)

      assert validated_user.hashed_password == "hashed_pw_123"
    end

    test "returns Left when hashed_password is empty string" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      invalid_user = %{user | hashed_password: ""}

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.ensure_valid_hashed_password(invalid_user)

      assert Enum.any?(errors, &String.contains?(&1, "must be a non-empty string or nil"))
    end

    test "returns Left when hashed_password is whitespace only" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      invalid_user = %{user | hashed_password: "   "}

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.ensure_valid_hashed_password(invalid_user)

      assert Enum.any?(errors, &String.contains?(&1, "must be a non-empty string or nil"))
    end

    test "returns Left when hashed_password is not a string" do
      user = unwrap_right(User.make("test@example.com", first_name: "John", last_name: "Doe"))
      invalid_user = %{user | hashed_password: 12345}

      assert %Either.Left{left: %ValidationError{errors: errors}} =
               User.ensure_valid_hashed_password(invalid_user)

      assert Enum.any?(errors, &String.contains?(&1, "must be a non-empty string or nil"))
    end
  end

  # Property-based tests
  describe "property-based validation" do
    property "make/2 returns Either for any email input" do
      check all(email <- string(:printable)) do
        result = User.make(email, first_name: "John", last_name: "Doe")

        assert match?(%Either.Right{}, result) or match?(%Either.Left{}, result)
      end
    end

    property "valid emails pass validation" do
      check all(
              local <- string(:alphanumeric, min_length: 1, max_length: 64),
              domain <- string(:alphanumeric, min_length: 1, max_length: 63),
              tld <- string(:alphanumeric, min_length: 2, max_length: 10)
            ) do
        email = "#{local}@#{domain}.#{tld}"

        if String.length(email) <= 160 do
          result = User.make(email, first_name: "John", last_name: "Doe")
          assert %Either.Right{} = result
        end
      end
    end

    property "emails without @ fail validation" do
      check all(str <- string(:alphanumeric, min_length: 1, max_length: 50)) do
        if not String.contains?(str, "@") do
          result = User.make(str, first_name: "John", last_name: "Doe")
          assert %Either.Left{} = result
        end
      end
    end

    property "names within length limits pass validation" do
      check all(name <- string(:alphanumeric, min_length: 1, max_length: 100)) do
        result = User.make("test@example.com", first_name: name, last_name: "Doe")
        assert %Either.Right{} = result
      end
    end

    property "names over 100 characters fail validation" do
      check all(name <- string(:alphanumeric, min_length: 101, max_length: 200)) do
        result = User.make("test@example.com", first_name: name, last_name: "Doe")
        assert %Either.Left{} = result
      end
    end
  end

  # Helper to unwrap Either.Right for setup
  defp unwrap_right(%Either.Right{right: value}), do: value
end

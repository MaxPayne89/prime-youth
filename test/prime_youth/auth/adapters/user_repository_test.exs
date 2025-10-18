defmodule PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepositoryTest do
  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepository
  alias PrimeYouth.Auth.Domain.Models.User

  describe "save/1" do
    test "saves a new user to the database" do
      {:ok, domain_user} =
        User.new(%{
          email: "test@example.com",
          first_name: "John",
          last_name: "Doe"
        })

      domain_user = %{domain_user | hashed_password: "hashed_password"}

      assert {:ok, saved_user} = EctoRepository.save(domain_user)
      assert saved_user.id != nil
      assert saved_user.email == "test@example.com"
      assert saved_user.first_name == "John"
      assert saved_user.last_name == "Doe"
    end

    test "returns error when email is already taken" do
      insert(:user, email: "test@example.com")

      {:ok, domain_user} =
        User.new(%{
          email: "test@example.com",
          first_name: "Jane",
          last_name: "Doe"
        })

      domain_user = %{domain_user | hashed_password: "hashed_password"}

      assert {:error, _changeset} = EctoRepository.save(domain_user)
    end
  end

  describe "find_by_id/1" do
    test "returns user when id exists" do
      user = insert(:user)

      assert {:ok, found_user} = EctoRepository.find_by_id(user.id)
      assert found_user.id == user.id
      assert found_user.email == user.email
    end

    test "returns error when id does not exist" do
      assert {:error, :not_found} = EctoRepository.find_by_id(999_999)
    end
  end

  describe "find_by_email/1" do
    test "returns user when email exists" do
      user = insert(:user, email: "test@example.com")

      assert {:ok, found_user} = EctoRepository.find_by_email("test@example.com")
      assert found_user.id == user.id
      assert found_user.email == "test@example.com"
    end

    test "is case-insensitive" do
      user = insert(:user, email: "test@example.com")

      assert {:ok, found_user} = EctoRepository.find_by_email("TEST@EXAMPLE.COM")
      assert found_user.id == user.id
    end

    test "returns error when email does not exist" do
      assert {:error, :not_found} = EctoRepository.find_by_email("nonexistent@example.com")
    end
  end

  describe "update/1" do
    test "updates an existing user" do
      user = insert(:user)

      {:ok, domain_user} =
        User.new(%{
          email: "updated@example.com",
          first_name: "Updated",
          last_name: "Name"
        })

      domain_user = %{domain_user | id: user.id}

      assert {:ok, updated_user} = EctoRepository.update(domain_user)
      assert updated_user.id == user.id
      assert updated_user.email == "updated@example.com"
      assert updated_user.first_name == "Updated"
      assert updated_user.last_name == "Name"
    end
  end

  describe "update_email/2" do
    test "updates user email" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)

      assert {:ok, updated_user} =
               EctoRepository.update_email(domain_user, "newemail@example.com")

      assert updated_user.email == "newemail@example.com"
    end
  end

  describe "update_password/2" do
    test "updates user password" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)
      new_hashed_password = "new_hashed_password"

      assert {:ok, updated_user} =
               EctoRepository.update_password(domain_user, new_hashed_password)

      assert updated_user.hashed_password == new_hashed_password
    end
  end

  describe "generate_session_token/1" do
    test "generates a session token for user" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)

      assert {:ok, token} = EctoRepository.generate_session_token(domain_user)
      assert is_binary(token)
      assert byte_size(token) > 0
    end
  end

  describe "find_by_session_token/1" do
    test "returns user and timestamp when token is valid" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)
      {:ok, token} = EctoRepository.generate_session_token(domain_user)

      assert {:ok, {found_user, authenticated_at}} = EctoRepository.find_by_session_token(token)
      assert found_user.id == user.id
      assert %DateTime{} = authenticated_at
    end

    test "returns error when token does not exist" do
      assert {:error, :not_found} = EctoRepository.find_by_session_token("invalid_token")
    end
  end

  describe "delete_session_token/1" do
    test "deletes a session token" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)
      {:ok, token} = EctoRepository.generate_session_token(domain_user)

      assert :ok = EctoRepository.delete_session_token(token)
      assert {:error, :not_found} = EctoRepository.find_by_session_token(token)
    end
  end

  describe "generate_email_token/2" do
    test "generates confirmation email token" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)

      assert {:ok, token} = EctoRepository.generate_email_token(domain_user, :confirmation)
      assert is_binary(token)
    end

    test "generates magic link token" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)

      assert {:ok, token} = EctoRepository.generate_email_token(domain_user, :magic_link)
      assert is_binary(token)
    end
  end

  describe "verify_email_token/2" do
    test "verifies valid confirmation token" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)
      {:ok, token} = EctoRepository.generate_email_token(domain_user, :confirmation)

      assert {:ok, verified_user} = EctoRepository.verify_email_token(token, :confirmation)
      assert verified_user.id == user.id
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} =
               EctoRepository.verify_email_token("invalid_token", :confirmation)
    end

    test "returns error for wrong context" do
      user = insert(:user)
      {:ok, domain_user} = EctoRepository.find_by_id(user.id)
      {:ok, token} = EctoRepository.generate_email_token(domain_user, :confirmation)

      assert {:error, :invalid_token} = EctoRepository.verify_email_token(token, :magic_link)
    end
  end
end

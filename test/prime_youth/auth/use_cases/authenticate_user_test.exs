defmodule PrimeYouth.Auth.Application.UseCases.AuthenticateUserTest do
  use PrimeYouth.DataCase, async: true

  import PrimeYouth.Factory

  alias PrimeYouth.Auth.Adapters.Driven.Persistence.Repositories.UserRepository
  alias PrimeYouth.Auth.Adapters.Driven.PasswordHashing.BcryptPasswordHasher
  alias PrimeYouth.Auth.Application.UseCases.AuthenticateUser

  describe "execute/3" do
    setup do
      # Create user using Factory
      user = insert(:user, hashed_password: Bcrypt.hash_pwd_salt("password123456"))
      %{user: user}
    end

    test "successfully authenticates user with valid email and password", %{user: user} do
      credentials = %{email: user.email, password: "password123456"}

      assert {:ok, authenticated_user} =
               AuthenticateUser.execute(
                 credentials,
                 UserRepository,
                 BcryptPasswordHasher
               )

      assert authenticated_user.id == user.id
      assert authenticated_user.email == user.email
    end

    test "returns error when email does not exist" do
      credentials = %{email: "nonexistent@example.com", password: "password123"}

      assert {:error, :invalid_credentials} =
               AuthenticateUser.execute(
                 credentials,
                 UserRepository,
                 BcryptPasswordHasher
               )
    end

    test "returns error when password is incorrect", %{user: user} do
      credentials = %{email: user.email, password: "wrongpassword"}

      assert {:error, :invalid_credentials} =
               AuthenticateUser.execute(
                 credentials,
                 UserRepository,
                 BcryptPasswordHasher
               )
    end

    test "returns error when user has no password set" do
      # Create user without password
      passwordless_user = insert(:user, hashed_password: nil)
      credentials = %{email: passwordless_user.email, password: "anypassword"}

      assert {:error, :invalid_credentials} =
               AuthenticateUser.execute(
                 credentials,
                 UserRepository,
                 BcryptPasswordHasher
               )
    end

    test "is case-insensitive for email", %{user: user} do
      credentials = %{email: String.upcase(user.email), password: "password123456"}

      assert {:ok, authenticated_user} =
               AuthenticateUser.execute(
                 credentials,
                 UserRepository,
                 BcryptPasswordHasher
               )

      assert authenticated_user.id == user.id
    end
  end
end

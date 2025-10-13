defmodule PrimeYouth.Auth.UseCases.RegisterUserTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.Auth.UseCases.RegisterUser
  alias PrimeYouth.Auth.Adapters.Driven.{EctoRepository, BcryptPasswordHasher, EmailNotifier}

  @valid_params %{
    email: "test@example.com",
    first_name: "John",
    last_name: "Doe",
    password: "password123456"
  }

  describe "execute/1" do
    test "successfully registers a new user with valid params" do
      assert {:ok, user} =
               RegisterUser.execute(
                 @valid_params,
                 EctoRepository,
                 BcryptPasswordHasher,
                 EmailNotifier
               )

      assert user.email == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.hashed_password != nil
      assert user.confirmed_at == nil
    end

    test "downcases email before saving" do
      params = %{@valid_params | email: "Test@EXAMPLE.COM"}

      assert {:ok, user} =
               RegisterUser.execute(params, EctoRepository, BcryptPasswordHasher, EmailNotifier)

      assert user.email == "test@example.com"
    end

    test "hashes the password" do
      assert {:ok, user} =
               RegisterUser.execute(
                 @valid_params,
                 EctoRepository,
                 BcryptPasswordHasher,
                 EmailNotifier
               )

      assert user.hashed_password != @valid_params.password
      assert Bcrypt.verify_pass(@valid_params.password, user.hashed_password)
    end

    test "returns error when email is already taken" do
      # First registration
      assert {:ok, _user} =
               RegisterUser.execute(
                 @valid_params,
                 EctoRepository,
                 BcryptPasswordHasher,
                 EmailNotifier
               )

      # Second registration with same email
      assert {:error, :email_taken} =
               RegisterUser.execute(
                 @valid_params,
                 EctoRepository,
                 BcryptPasswordHasher,
                 EmailNotifier
               )
    end

    test "returns error when email is invalid" do
      params = %{@valid_params | email: "not-an-email"}

      assert {:error, :invalid_email_format} =
               RegisterUser.execute(params, EctoRepository, BcryptPasswordHasher, EmailNotifier)
    end

    test "returns error when first_name is missing" do
      params = Map.delete(@valid_params, :first_name)

      assert {:error, :first_name_required} =
               RegisterUser.execute(params, EctoRepository, BcryptPasswordHasher, EmailNotifier)
    end

    test "returns error when last_name is missing" do
      params = Map.delete(@valid_params, :last_name)

      assert {:error, :last_name_required} =
               RegisterUser.execute(params, EctoRepository, BcryptPasswordHasher, EmailNotifier)
    end

    test "generates confirmation token" do
      assert {:ok, user} =
               RegisterUser.execute(
                 @valid_params,
                 EctoRepository,
                 BcryptPasswordHasher,
                 EmailNotifier
               )

      # Verify token was created
      token =
        PrimeYouth.Repo.get_by(PrimeYouth.Auth.Infrastructure.UserToken,
          user_id: user.id,
          context: "confirm"
        )

      assert token != nil
    end
  end
end

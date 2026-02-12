defmodule KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepositoryTest do
  use KlassHero.DataCase, async: true

  import KlassHero.AccountsFixtures

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Repositories.UserRepository
  alias KlassHero.Accounts.Domain.Models.User, as: DomainUser

  describe "get_by_id/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_id(schema.id)
      assert user.id == schema.id
      assert user.email == schema.email
    end

    test "returns error when not found" do
      assert {:error, :not_found} =
               UserRepository.get_by_id("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "get_by_email/1" do
    test "returns domain user when found" do
      schema = user_fixture()

      assert {:ok, %DomainUser{} = user} = UserRepository.get_by_email(schema.email)
      assert user.email == schema.email
    end

    test "returns error when not found" do
      assert {:error, :not_found} = UserRepository.get_by_email("nonexistent@example.com")
    end
  end

  describe "exists?/1" do
    test "returns true when user exists" do
      schema = user_fixture()
      assert UserRepository.exists?(schema.id)
    end

    test "returns false when user does not exist" do
      refute UserRepository.exists?("00000000-0000-0000-0000-000000000000")
    end
  end

  describe "register/1" do
    test "creates user with valid attributes" do
      attrs = valid_user_attributes()
      assert {:ok, user} = UserRepository.register(attrs)
      assert user.email == attrs.email
      assert user.name == attrs.name
    end

    test "returns error changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = UserRepository.register(%{})
    end

    test "returns error changeset with duplicate email" do
      attrs = valid_user_attributes()
      {:ok, _} = UserRepository.register(attrs)
      assert {:error, %Ecto.Changeset{}} = UserRepository.register(attrs)
    end
  end

  describe "anonymize/1" do
    test "anonymizes user PII and deletes tokens" do
      user = user_fixture()

      # Generate a session token to verify cleanup
      token = KlassHero.Accounts.generate_user_session_token(user)

      assert {:ok, anonymized} = UserRepository.anonymize(user)
      assert anonymized.email == "deleted_#{user.id}@anonymized.local"
      assert anonymized.name == "Deleted User"
      assert anonymized.avatar == nil

      # Verify token was deleted
      assert KlassHero.Accounts.get_user_by_session_token(token) == nil
    end
  end

  describe "apply_email_change/2" do
    test "updates email with valid token" do
      user = user_fixture()
      new_email = unique_user_email()

      # Simulate the email change flow: user requests a change to new_email,
      # so the token is created with sent_to=new_email and context="change:old_email"
      user_with_new_email = %{user | email: new_email}

      token =
        extract_user_token(fn url ->
          KlassHero.Accounts.deliver_user_update_email_instructions(
            user_with_new_email,
            user.email,
            url
          )
        end)

      assert {:ok, updated} = UserRepository.apply_email_change(user, token)
      assert updated.email == new_email
    end

    test "returns invalid_token for malformed token" do
      user = user_fixture()

      assert {:error, :invalid_token} =
               UserRepository.apply_email_change(user, "not-valid-base64!@#")
    end

    test "returns invalid_token for nonexistent token" do
      user = user_fixture()
      fake_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      assert {:error, :invalid_token} = UserRepository.apply_email_change(user, fake_token)
    end
  end

  describe "resolve_magic_link/1" do
    test "returns {:confirmed, user, token} for confirmed user" do
      user = user_fixture()
      {encoded_token, _raw} = generate_user_magic_link_token(user)

      assert {:ok, {:confirmed, resolved_user, token_record}} =
               UserRepository.resolve_magic_link(encoded_token)

      assert resolved_user.id == user.id
      assert token_record.__struct__ == KlassHero.Accounts.UserToken
    end

    test "returns {:unconfirmed, user} for unconfirmed user without password" do
      user = unconfirmed_user_fixture()
      {encoded_token, _raw} = generate_user_magic_link_token(user)

      assert {:ok, {:unconfirmed, resolved_user}} =
               UserRepository.resolve_magic_link(encoded_token)

      assert resolved_user.id == user.id
    end

    test "returns :security_violation for unconfirmed user with password" do
      user = unconfirmed_user_fixture()
      user = set_password(user)
      {encoded_token, _raw} = generate_user_magic_link_token(user)

      assert {:error, :security_violation} =
               UserRepository.resolve_magic_link(encoded_token)
    end

    test "returns :invalid_token for malformed token" do
      assert {:error, :invalid_token} = UserRepository.resolve_magic_link("not-valid!@#")
    end

    test "returns :not_found for nonexistent token" do
      fake_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      assert {:error, :not_found} = UserRepository.resolve_magic_link(fake_token)
    end

    test "returns :not_found for expired token" do
      user = user_fixture()
      {encoded_token, raw_token} = generate_user_magic_link_token(user)

      # Push token insertion time back beyond validity window
      offset_user_token(raw_token, -20, :minute)

      assert {:error, :not_found} = UserRepository.resolve_magic_link(encoded_token)
    end
  end

  describe "confirm_and_cleanup_tokens/1" do
    test "confirms user and deletes all tokens" do
      user = unconfirmed_user_fixture()
      _token = KlassHero.Accounts.generate_user_session_token(user)

      assert {:ok, {confirmed_user, _tokens}} =
               UserRepository.confirm_and_cleanup_tokens(user)

      assert confirmed_user.confirmed_at != nil
    end
  end

  describe "delete_token/1" do
    test "deletes an existing token" do
      user = user_fixture()
      {_encoded, user_token} = KlassHero.Accounts.UserToken.build_email_token(user, "login")
      {:ok, inserted_token} = KlassHero.Repo.insert(user_token)

      assert :ok = UserRepository.delete_token(inserted_token)
    end
  end
end

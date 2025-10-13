defmodule PrimeYouth.AuthFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PrimeYouth.Auth` bounded context.
  """

  import Ecto.Query

  alias PrimeYouth.Auth.Adapters.Driven.{EctoRepository, BcryptPasswordHasher, EmailNotifier}
  alias PrimeYouth.Auth.Infrastructure.{Scope, User, UserToken}
  alias PrimeYouth.Auth.UseCases.{RegisterUser, LoginWithMagicLink}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      first_name: "Test",
      last_name: "User"
      # No password by default - supports passwordless authentication flow
      # Tests can add password: valid_user_password() via attrs parameter
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    params = valid_user_attributes(attrs)

    # Create passwordless user directly via Ecto (bypasses RegisterUser use case)
    # This allows magic link confirmation flow to work without business rule violations
    %User{}
    |> User.passwordless_registration_changeset(params)
    |> PrimeYouth.Repo.insert!()
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    # Generate magic link token directly for testing (no email sending needed)
    {:ok, domain_user} = EctoRepository.find_by_id(user.id)
    {:ok, token} = EctoRepository.generate_email_token(domain_user, :magic_link)

    # Login with magic link to confirm the user
    {:ok, {confirmed_domain_user, _expired_tokens}} =
      LoginWithMagicLink.execute(token, EctoRepository)

    # Convert back to schema for compatibility
    PrimeYouth.Repo.get!(User, confirmed_domain_user.id)
  end

  @doc """
  Creates an unconfirmed user with a password.

  For tests that specifically need users registered with passwords
  (e.g., testing password-based login flows, password change, etc.)
  """
  def user_with_password_fixture(attrs \\ %{}) do
    params = valid_user_attributes(Map.put(attrs, :password, valid_user_password()))

    {:ok, domain_user} =
      RegisterUser.execute(params, EctoRepository, BcryptPasswordHasher, EmailNotifier)

    # Convert domain user back to schema for compatibility with existing tests
    PrimeYouth.Repo.get!(User, domain_user.id)
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, domain_user} = EctoRepository.find_by_id(user.id)
    {:ok, hashed_password} = BcryptPasswordHasher.hash(valid_user_password())
    {:ok, updated_domain_user} = EctoRepository.update_password(domain_user, hashed_password)

    # Convert back to schema for compatibility
    PrimeYouth.Repo.get!(User, updated_domain_user.id)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    PrimeYouth.Repo.update_all(
      from(t in UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    PrimeYouth.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    PrimeYouth.Repo.update_all(
      from(ut in UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end

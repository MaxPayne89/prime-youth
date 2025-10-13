defmodule PrimeYouth.Factory do
  @moduledoc """
  Main factory module that consolidates all domain factories.
  Import this module in tests to access all factory functions.
  """

  use ExMachina.Ecto, repo: PrimeYouth.Repo

  alias PrimeYouth.Auth.Infrastructure.User

  # Auth factories
  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      confirmed_at: DateTime.utc_now()
    }
  end

  def unconfirmed_user_factory do
    struct!(
      user_factory(),
      %{confirmed_at: nil}
    )
  end

  def user_with_password_factory do
    user_factory()
  end
end

defmodule PrimeYouth.ProgramCatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities in the Program Catalog context.
  """

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Provider
  alias PrimeYouth.Repo

  @doc """
  Generate a provider with an associated user.

  If no `user_id` is provided in attrs, a new user will be created
  via AccountsFixtures.user_fixture/0.
  """
  def provider_fixture(attrs \\ %{}) do
    # Create a real user if user_id not provided
    user =
      if !Map.has_key?(attrs, :user_id) do
        PrimeYouth.AccountsFixtures.user_fixture()
      end

    default_attrs = %{
      name: "Test Provider #{System.unique_integer([:positive])}",
      email: unique_provider_email(),
      is_verified: true,
      is_prime_youth: false,
      user_id: user && user.id
    }

    attrs = Map.merge(default_attrs, Map.new(attrs))

    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Generate a unique provider email.
  """
  def unique_provider_email do
    "provider#{System.unique_integer([:positive])}@example.com"
  end
end

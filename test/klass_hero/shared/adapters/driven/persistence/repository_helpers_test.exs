defmodule KlassHero.Shared.Adapters.Driven.Persistence.RepositoryHelpersTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Accounts.Adapters.Driven.Persistence.Mappers.UserMapper
  alias KlassHero.Accounts.User
  alias KlassHero.Shared.Adapters.Driven.Persistence.RepositoryHelpers

  describe "get_by_id/3" do
    test "returns {:ok, domain_struct} when record exists" do
      user = KlassHero.AccountsFixtures.user_fixture()

      assert {:ok, domain} = RepositoryHelpers.get_by_id(User, user.id, UserMapper)
      assert domain.id == user.id
      assert domain.email == user.email
    end

    test "returns {:error, :not_found} when record does not exist" do
      assert {:error, :not_found} =
               RepositoryHelpers.get_by_id(User, Ecto.UUID.generate(), UserMapper)
    end
  end
end

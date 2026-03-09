defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.ProviderProfileSchema

  describe "admin_changeset/3" do
    setup do
      user = KlassHero.AccountsFixtures.unconfirmed_user_fixture(intended_roles: [:provider])

      {:ok, schema} =
        %ProviderProfileSchema{}
        |> ProviderProfileSchema.changeset(%{
          identity_id: user.id,
          business_name: "Test Business"
        })
        |> KlassHero.Repo.insert()

      %{schema: schema}
    end

    test "casts verified and subscription_tier", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(
          schema,
          %{
            verified: true,
            subscription_tier: "professional"
          },
          %{}
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :verified) == true
      assert Ecto.Changeset.get_change(changeset, :subscription_tier) == "professional"
    end

    test "ignores provider-owned fields", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(
          schema,
          %{
            business_name: "Hacked Name",
            description: "Hacked Desc",
            phone: "555-HACK",
            website: "https://hacked.com",
            address: "Hacked Address"
          },
          %{}
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :business_name) == nil
      assert Ecto.Changeset.get_change(changeset, :description) == nil
      assert Ecto.Changeset.get_change(changeset, :phone) == nil
      assert Ecto.Changeset.get_change(changeset, :website) == nil
      assert Ecto.Changeset.get_change(changeset, :address) == nil
    end

    test "validates subscription_tier inclusion", %{schema: schema} do
      changeset =
        ProviderProfileSchema.admin_changeset(
          schema,
          %{
            subscription_tier: "invalid_tier"
          },
          %{}
        )

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:subscription_tier]
    end
  end
end

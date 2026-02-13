defmodule KlassHero.Family.Application.UseCases.Consents.WithdrawConsentTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Family.Application.UseCases.Consents.GrantConsent
  alias KlassHero.Family.Application.UseCases.Consents.WithdrawConsent
  alias KlassHero.Family.Domain.Models.Consent

  describe "execute/2" do
    test "withdraws active consent" do
      child_schema = insert(:child_schema)

      {:ok, granted} =
        GrantConsent.execute(%{
          parent_id: child_schema.parent_id,
          child_id: child_schema.id,
          consent_type: "provider_data_sharing"
        })

      assert {:ok, %Consent{} = withdrawn} =
               WithdrawConsent.execute(child_schema.id, "provider_data_sharing")

      assert withdrawn.id == granted.id
      assert %DateTime{} = withdrawn.withdrawn_at
    end

    test "returns :not_found when no active consent exists" do
      assert {:error, :not_found} =
               WithdrawConsent.execute(Ecto.UUID.generate(), "provider_data_sharing")
    end

    test "returns :not_found when consent was already withdrawn" do
      child_schema = insert(:child_schema)

      {:ok, _} =
        GrantConsent.execute(%{
          parent_id: child_schema.parent_id,
          child_id: child_schema.id,
          consent_type: "provider_data_sharing"
        })

      {:ok, _} = WithdrawConsent.execute(child_schema.id, "provider_data_sharing")

      assert {:error, :not_found} =
               WithdrawConsent.execute(child_schema.id, "provider_data_sharing")
    end
  end
end

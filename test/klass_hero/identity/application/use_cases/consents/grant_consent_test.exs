defmodule KlassHero.Identity.Application.UseCases.Consents.GrantConsentTest do
  use KlassHero.DataCase, async: true

  import KlassHero.Factory

  alias KlassHero.Identity.Application.UseCases.Consents.GrantConsent
  alias KlassHero.Identity.Domain.Models.Consent

  describe "execute/1" do
    test "grants consent with valid params" do
      child_schema = insert(:child_schema)

      attrs = %{
        parent_id: child_schema.parent_id,
        child_id: child_schema.id,
        consent_type: "provider_data_sharing"
      }

      assert {:ok, %Consent{} = consent} = GrantConsent.execute(attrs)
      assert consent.parent_id == child_schema.parent_id
      assert consent.child_id == child_schema.id
      assert consent.consent_type == "provider_data_sharing"
      assert %DateTime{} = consent.granted_at
      assert is_nil(consent.withdrawn_at)
    end

    test "auto-generates id and granted_at" do
      child_schema = insert(:child_schema)

      attrs = %{
        parent_id: child_schema.parent_id,
        child_id: child_schema.id,
        consent_type: "provider_data_sharing"
      }

      {:ok, consent} = GrantConsent.execute(attrs)

      assert is_binary(consent.id)
      assert %DateTime{} = consent.granted_at
    end

    test "returns validation error for empty consent_type" do
      child_schema = insert(:child_schema)

      attrs = %{
        parent_id: child_schema.parent_id,
        child_id: child_schema.id,
        consent_type: ""
      }

      assert {:error, {:validation_error, errors}} = GrantConsent.execute(attrs)
      assert is_list(errors)
    end

    test "returns validation error for missing child_id" do
      parent = insert(:parent_profile_schema)

      attrs = %{
        parent_id: parent.id,
        child_id: "",
        consent_type: "provider_data_sharing"
      }

      assert {:error, {:validation_error, errors}} = GrantConsent.execute(attrs)
      assert is_list(errors)
    end
  end
end

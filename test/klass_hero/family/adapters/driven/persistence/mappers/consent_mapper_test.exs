defmodule KlassHero.Family.Adapters.Driven.Persistence.Mappers.ConsentMapperTest do
  @moduledoc """
  Unit tests for ConsentMapper.

  Tests schema-to-domain mapping from ConsentSchema to Consent domain entities.
  No database required — schemas are constructed inline.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Adapters.Driven.Persistence.Mappers.ConsentMapper
  alias KlassHero.Family.Adapters.Driven.Persistence.Schemas.ConsentSchema
  alias KlassHero.Family.Domain.Models.Consent

  @parent_id Ecto.UUID.generate()
  @child_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: Ecto.UUID.generate(),
      parent_id: @parent_id,
      child_id: @child_id,
      consent_type: "provider_data_sharing",
      granted_at: ~U[2025-09-01 10:00:00Z],
      withdrawn_at: nil,
      inserted_at: ~U[2025-09-01 10:00:00Z],
      updated_at: ~U[2025-09-01 10:00:00Z]
    }

    struct!(ConsentSchema, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "converts a valid schema to a Consent domain entity" do
      schema = valid_schema()

      consent = ConsentMapper.to_domain(schema)

      assert %Consent{} = consent
      assert consent.parent_id == Ecto.UUID.cast!(schema.parent_id)
      assert consent.child_id == Ecto.UUID.cast!(schema.child_id)
      assert consent.consent_type == "provider_data_sharing"
      assert consent.granted_at == ~U[2025-09-01 10:00:00Z]
      assert consent.withdrawn_at == nil
    end

    test "maps all supported consent types" do
      for consent_type <- Consent.valid_consent_types() do
        schema = valid_schema(%{consent_type: consent_type})

        consent = ConsentMapper.to_domain(schema)

        assert consent.consent_type == consent_type
      end
    end

    test "preserves withdrawn_at when set" do
      withdrawn = ~U[2025-10-15 14:30:00Z]
      schema = valid_schema(%{withdrawn_at: withdrawn})

      consent = ConsentMapper.to_domain(schema)

      assert consent.withdrawn_at == withdrawn
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      consent = ConsentMapper.to_domain(schema)

      assert consent.inserted_at == schema.inserted_at
      assert consent.updated_at == schema.updated_at
    end

    test "maps id field as a string UUID" do
      schema = valid_schema()

      consent = ConsentMapper.to_domain(schema)

      assert consent.id == Ecto.UUID.cast!(schema.id)
      assert {:ok, _} = Ecto.UUID.cast(consent.id)
    end
  end
end

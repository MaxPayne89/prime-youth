defmodule KlassHero.Family.Domain.Models.ConsentTest do
  @moduledoc """
  Tests for the Consent domain entity.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Family.Domain.Models.Consent

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    parent_id: "660e8400-e29b-41d4-a716-446655440001",
    child_id: "770e8400-e29b-41d4-a716-446655440002",
    consent_type: "photo",
    granted_at: ~U[2025-06-15 10:00:00Z]
  }

  describe "valid_consent_types/0" do
    test "returns known consent types" do
      types = Consent.valid_consent_types()

      assert is_list(types)
      assert "provider_data_sharing" in types
      assert "photo" in types
      assert "medical" in types
      assert "participation" in types
    end
  end

  describe "new/1 with valid attributes" do
    test "accepts all valid consent types" do
      for type <- Consent.valid_consent_types() do
        attrs = %{@valid_attrs | consent_type: type}
        assert {:ok, _consent} = Consent.new(attrs)
      end
    end

    test "creates consent with all fields" do
      attrs =
        Map.put(@valid_attrs, :withdrawn_at, ~U[2025-07-01 12:00:00Z])

      assert {:ok, consent} = Consent.new(attrs)
      assert consent.id == attrs.id
      assert consent.parent_id == attrs.parent_id
      assert consent.child_id == attrs.child_id
      assert consent.consent_type == "photo"
      assert consent.granted_at == ~U[2025-06-15 10:00:00Z]
      assert consent.withdrawn_at == ~U[2025-07-01 12:00:00Z]
    end

    test "creates consent with only required fields" do
      assert {:ok, consent} = Consent.new(@valid_attrs)
      assert is_nil(consent.withdrawn_at)
      assert is_nil(consent.inserted_at)
      assert is_nil(consent.updated_at)
    end
  end

  describe "new/1 validation errors" do
    test "returns error when parent_id is empty" do
      attrs = %{@valid_attrs | parent_id: ""}

      assert {:error, errors} = Consent.new(attrs)
      assert "Parent ID cannot be empty" in errors
    end

    test "returns error when child_id is empty" do
      attrs = %{@valid_attrs | child_id: ""}

      assert {:error, errors} = Consent.new(attrs)
      assert "Child ID cannot be empty" in errors
    end

    test "returns error when consent_type is empty" do
      attrs = %{@valid_attrs | consent_type: ""}

      assert {:error, errors} = Consent.new(attrs)
      assert "Consent type cannot be empty" in errors
    end

    test "returns error when granted_at is not a DateTime" do
      attrs = %{@valid_attrs | granted_at: "2025-06-15"}

      assert {:error, errors} = Consent.new(attrs)
      assert "Granted at must be a DateTime" in errors
    end

    test "returns error when consent_type is not a known type" do
      attrs = %{@valid_attrs | consent_type: "typo_consent"}

      assert {:error, errors} = Consent.new(attrs)
      assert Enum.any?(errors, &String.contains?(&1, "must be one of"))
    end
  end

  describe "from_persistence/1" do
    test "reconstructs consent from valid persistence data" do
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        child_id: "770e8400-e29b-41d4-a716-446655440002",
        consent_type: "photo",
        granted_at: ~U[2025-06-15 10:00:00Z],
        withdrawn_at: nil,
        inserted_at: ~U[2025-06-15 10:00:00Z],
        updated_at: ~U[2025-06-15 10:00:00Z]
      }

      assert {:ok, consent} = Consent.from_persistence(attrs)
      assert consent.id == attrs.id
      assert consent.consent_type == "photo"
    end

    test "returns error when required key is missing" do
      # Missing :granted_at which is in @enforce_keys
      attrs = %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        child_id: "770e8400-e29b-41d4-a716-446655440002",
        consent_type: "photo"
      }

      assert {:error, :invalid_persistence_data} = Consent.from_persistence(attrs)
    end
  end

  describe "active?/1" do
    test "returns true when withdrawn_at is nil" do
      {:ok, consent} = Consent.new(@valid_attrs)

      assert Consent.active?(consent)
    end

    test "returns false when withdrawn_at is set" do
      attrs = Map.put(@valid_attrs, :withdrawn_at, ~U[2025-07-01 12:00:00Z])
      {:ok, consent} = Consent.new(attrs)

      refute Consent.active?(consent)
    end
  end

  describe "withdraw/1" do
    test "withdraws an active consent" do
      {:ok, consent} = Consent.new(@valid_attrs)

      assert {:ok, withdrawn} = Consent.withdraw(consent)
      assert %DateTime{} = withdrawn.withdrawn_at
      assert withdrawn.id == consent.id
      assert withdrawn.consent_type == consent.consent_type
    end

    test "returns error when consent is already withdrawn" do
      attrs = Map.put(@valid_attrs, :withdrawn_at, ~U[2025-07-01 12:00:00Z])
      {:ok, consent} = Consent.new(attrs)

      assert {:error, :already_withdrawn} = Consent.withdraw(consent)
    end
  end

  describe "valid?/1" do
    test "returns true for valid consent" do
      {:ok, consent} = Consent.new(@valid_attrs)

      assert Consent.valid?(consent)
    end

    test "returns false for consent with empty consent_type" do
      consent = %Consent{
        id: "550e8400-e29b-41d4-a716-446655440000",
        parent_id: "660e8400-e29b-41d4-a716-446655440001",
        child_id: "770e8400-e29b-41d4-a716-446655440002",
        consent_type: "",
        granted_at: ~U[2025-06-15 10:00:00Z]
      }

      refute Consent.valid?(consent)
    end
  end
end

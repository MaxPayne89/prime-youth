defmodule KlassHero.Provider.Adapters.Driven.Persistence.Mappers.StaffMemberMapperTest do
  @moduledoc """
  Unit tests for StaffMemberMapper.

  Covers schema-to-domain and domain-to-persistence mappings,
  with special attention to invitation_status atomization, nil-guard fields,
  and conditional ID inclusion. No database required.
  """

  use ExUnit.Case, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Mappers.StaffMemberMapper
  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema
  alias KlassHero.Provider.Domain.Models.StaffMember

  @id Ecto.UUID.generate()
  @provider_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  defp valid_schema(overrides \\ %{}) do
    defaults = %{
      id: @id,
      provider_id: @provider_id,
      first_name: "Alice",
      last_name: "Smith",
      role: "Coach",
      email: "alice@example.com",
      bio: "Experienced coach",
      headshot_url: "https://example.com/photo.jpg",
      tags: ["football"],
      qualifications: ["UEFA B License"],
      active: true,
      user_id: @user_id,
      invitation_status: "accepted",
      invitation_token_hash: nil,
      invitation_sent_at: nil,
      inserted_at: ~U[2025-01-01 10:00:00Z],
      updated_at: ~U[2025-01-02 10:00:00Z]
    }

    struct!(StaffMemberSchema, Map.merge(defaults, overrides))
  end

  defp valid_domain(overrides \\ %{}) do
    defaults = %{
      id: @id,
      provider_id: @provider_id,
      first_name: "Alice",
      last_name: "Smith",
      role: "Coach",
      email: "alice@example.com",
      bio: "Experienced coach",
      headshot_url: "https://example.com/photo.jpg",
      tags: ["football"],
      qualifications: ["UEFA B License"],
      active: true,
      user_id: @user_id,
      invitation_status: :accepted,
      invitation_token_hash: nil,
      invitation_sent_at: nil
    }

    struct!(StaffMember, Map.merge(defaults, overrides))
  end

  describe "to_domain/1" do
    test "maps all basic fields from schema to domain struct" do
      schema = valid_schema()

      staff = StaffMemberMapper.to_domain(schema)

      assert %StaffMember{} = staff
      assert staff.id == @id
      assert staff.provider_id == @provider_id
      assert staff.first_name == "Alice"
      assert staff.last_name == "Smith"
      assert staff.role == "Coach"
      assert staff.email == "alice@example.com"
      assert staff.bio == "Experienced coach"
      assert staff.headshot_url == "https://example.com/photo.jpg"
      assert staff.tags == ["football"]
      assert staff.qualifications == ["UEFA B License"]
      assert staff.active == true
    end

    test "converts UUID binary fields to strings" do
      schema = valid_schema()

      staff = StaffMemberMapper.to_domain(schema)

      assert is_binary(staff.id)
      assert is_binary(staff.provider_id)
      assert is_binary(staff.user_id)
    end

    test "converts string invitation_status to atom" do
      schema = valid_schema(%{invitation_status: "pending"})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.invitation_status == :pending
    end

    test "converts all valid invitation_status strings to atoms" do
      for status_str <- ~w[pending sent failed accepted expired] do
        schema = valid_schema(%{invitation_status: status_str})
        staff = StaffMemberMapper.to_domain(schema)
        assert staff.invitation_status == String.to_existing_atom(status_str)
      end
    end

    test "passes through atom invitation_status unchanged" do
      schema = valid_schema(%{invitation_status: :sent})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.invitation_status == :sent
    end

    test "maps nil invitation_status to nil" do
      schema = valid_schema(%{invitation_status: nil})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.invitation_status == nil
    end

    test "maps nil user_id to nil (no to_string)" do
      schema = valid_schema(%{user_id: nil})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.user_id == nil
    end

    test "defaults nil tags to empty list" do
      schema = valid_schema(%{tags: nil})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.tags == []
    end

    test "defaults nil qualifications to empty list" do
      schema = valid_schema(%{qualifications: nil})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.qualifications == []
    end

    test "preserves timestamps from schema" do
      schema = valid_schema()

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.inserted_at == ~U[2025-01-01 10:00:00Z]
      assert staff.updated_at == ~U[2025-01-02 10:00:00Z]
    end

    test "maps invitation_token_hash and invitation_sent_at" do
      token_hash = :crypto.hash(:sha256, "test")
      sent_at = ~U[2025-06-01 09:00:00.000000Z]
      schema = valid_schema(%{invitation_token_hash: token_hash, invitation_sent_at: sent_at})

      staff = StaffMemberMapper.to_domain(schema)

      assert staff.invitation_token_hash == token_hash
      assert staff.invitation_sent_at == sent_at
    end
  end

  describe "to_schema/1" do
    test "maps all fields to a plain map" do
      domain = valid_domain()

      attrs = StaffMemberMapper.to_schema(domain)

      assert attrs.provider_id == @provider_id
      assert attrs.first_name == "Alice"
      assert attrs.last_name == "Smith"
      assert attrs.role == "Coach"
      assert attrs.email == "alice@example.com"
      assert attrs.bio == "Experienced coach"
      assert attrs.headshot_url == "https://example.com/photo.jpg"
      assert attrs.tags == ["football"]
      assert attrs.qualifications == ["UEFA B License"]
      assert attrs.active == true
      assert attrs.user_id == @user_id
    end

    test "converts atom invitation_status to string" do
      domain = valid_domain(%{invitation_status: :pending})

      attrs = StaffMemberMapper.to_schema(domain)

      assert attrs.invitation_status == "pending"
    end

    test "maps nil invitation_status to nil" do
      domain = valid_domain(%{invitation_status: nil})

      attrs = StaffMemberMapper.to_schema(domain)

      assert attrs.invitation_status == nil
    end

    test "includes id when present" do
      domain = valid_domain()

      attrs = StaffMemberMapper.to_schema(domain)

      assert attrs.id == @id
    end

    test "excludes id when nil" do
      domain = valid_domain(%{id: nil})

      attrs = StaffMemberMapper.to_schema(domain)

      refute Map.has_key?(attrs, :id)
    end

    test "does not include timestamps" do
      domain = valid_domain()

      attrs = StaffMemberMapper.to_schema(domain)

      refute Map.has_key?(attrs, :inserted_at)
      refute Map.has_key?(attrs, :updated_at)
    end
  end
end

defmodule KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Provider.Adapters.Driven.Persistence.Schemas.StaffMemberSchema

  describe "admin_changeset/3" do
    setup do
      schema = %StaffMemberSchema{
        id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate(),
        first_name: "Jane",
        last_name: "Doe",
        role: "Instructor",
        email: "jane@example.com",
        bio: "A bio",
        active: true,
        tags: ["sports"],
        qualifications: ["CPR"]
      }

      # Trigger: Backpex passes metadata with assigns as 3rd arg
      # Why: admin_changeset must accept 3-arg signature even if unused
      # Outcome: matches Backpex callback contract
      metadata = [assigns: %{current_scope: %{user: %{id: Ecto.UUID.generate()}}}]

      %{schema: schema, metadata: metadata}
    end

    test "casts active field", %{schema: schema, metadata: metadata} do
      changeset = StaffMemberSchema.admin_changeset(schema, %{"active" => false}, metadata)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :active) == false
    end

    test "ignores non-admin fields", %{schema: schema, metadata: metadata} do
      changeset =
        StaffMemberSchema.admin_changeset(
          schema,
          %{"first_name" => "Hacked", "role" => "CEO", "email" => "hacked@evil.com"},
          metadata
        )

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :first_name)
      refute Ecto.Changeset.get_change(changeset, :role)
      refute Ecto.Changeset.get_change(changeset, :email)
    end

    test "returns valid changeset with no changes", %{schema: schema, metadata: metadata} do
      changeset = StaffMemberSchema.admin_changeset(schema, %{}, metadata)
      assert changeset.valid?
    end
  end

  describe "create_changeset/2 pay rate fields" do
    @base_attrs %{first_name: "Mike", last_name: "Johnson", provider_id: Ecto.UUID.generate()}

    test "accepts a valid hourly rate" do
      attrs =
        Map.merge(@base_attrs, %{
          rate_type: "hourly",
          rate_amount: Decimal.new("25.00"),
          rate_currency: "EUR"
        })

      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :rate_type) == :hourly
      assert Ecto.Changeset.get_change(changeset, :rate_currency) == :EUR
    end

    test "accepts a valid per_session rate" do
      attrs =
        Map.merge(@base_attrs, %{
          rate_type: "per_session",
          rate_amount: Decimal.new("80.00"),
          rate_currency: "EUR"
        })

      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      assert changeset.valid?
    end

    test "is valid when no rate fields are set" do
      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, @base_attrs)
      assert changeset.valid?
    end

    test "rejects partial rate — amount without type or currency" do
      attrs = Map.put(@base_attrs, :rate_amount, Decimal.new("25.00"))
      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      refute changeset.valid?
      assert %{rate_type: [_ | _]} = errors_on(changeset)
    end

    test "rejects negative rate amount" do
      attrs =
        Map.merge(@base_attrs, %{
          rate_type: "hourly",
          rate_amount: Decimal.new("-5.00"),
          rate_currency: "EUR"
        })

      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      refute changeset.valid?
      assert %{rate_amount: [_ | _]} = errors_on(changeset)
    end

    test "rejects unknown rate_type" do
      attrs =
        Map.merge(@base_attrs, %{
          rate_type: "weekly",
          rate_amount: Decimal.new("100.00"),
          rate_currency: "EUR"
        })

      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      refute changeset.valid?
      assert %{rate_type: [_ | _]} = errors_on(changeset)
    end

    test "rejects unknown currency" do
      attrs =
        Map.merge(@base_attrs, %{
          rate_type: "hourly",
          rate_amount: Decimal.new("25.00"),
          rate_currency: "USD"
        })

      changeset = StaffMemberSchema.create_changeset(%StaffMemberSchema{}, attrs)

      refute changeset.valid?
      assert %{rate_currency: [_ | _]} = errors_on(changeset)
    end
  end

  describe "edit_changeset/2 pay rate fields" do
    setup do
      schema = %StaffMemberSchema{
        id: Ecto.UUID.generate(),
        provider_id: Ecto.UUID.generate(),
        first_name: "Jane",
        last_name: "Doe",
        active: true,
        tags: [],
        qualifications: []
      }

      %{schema: schema}
    end

    test "accepts setting a rate on existing staff", %{schema: schema} do
      changeset =
        StaffMemberSchema.edit_changeset(schema, %{
          "rate_type" => "hourly",
          "rate_amount" => "30.00",
          "rate_currency" => "EUR"
        })

      assert changeset.valid?
    end

    test "accepts clearing all rate fields back to nil", %{schema: schema} do
      schema_with_rate = %{
        schema
        | rate_type: "hourly",
          rate_amount: Decimal.new("25.00"),
          rate_currency: "EUR"
      }

      changeset =
        StaffMemberSchema.edit_changeset(schema_with_rate, %{
          "rate_type" => nil,
          "rate_amount" => nil,
          "rate_currency" => nil
        })

      assert changeset.valid?
    end

    test "rejects partial update (clear type only)", %{schema: schema} do
      schema_with_rate = %{
        schema
        | rate_type: "hourly",
          rate_amount: Decimal.new("25.00"),
          rate_currency: "EUR"
      }

      changeset = StaffMemberSchema.edit_changeset(schema_with_rate, %{"rate_type" => nil})

      refute changeset.valid?
    end
  end
end

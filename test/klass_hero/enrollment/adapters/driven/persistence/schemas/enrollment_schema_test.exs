defmodule KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.Enrollment.Adapters.Driven.Persistence.Schemas.EnrollmentSchema

  describe "create_changeset/2" do
    test "valid changeset with all required fields" do
      attrs = valid_attrs()

      changeset = EnrollmentSchema.create_changeset(attrs)

      assert changeset.valid?
    end

    test "valid changeset with optional fields" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          subtotal: Decimal.new("100.00"),
          vat_amount: Decimal.new("19.00"),
          card_fee_amount: Decimal.new("2.00"),
          total_amount: Decimal.new("121.00"),
          payment_method: "card",
          special_requirements: "Allergic to nuts"
        })

      changeset = EnrollmentSchema.create_changeset(attrs)

      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = EnrollmentSchema.create_changeset(%{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).program_id
      assert "can't be blank" in errors_on(changeset).child_id
      assert "can't be blank" in errors_on(changeset).parent_id
      assert "can't be blank" in errors_on(changeset).status
      assert "can't be blank" in errors_on(changeset).enrolled_at
    end

    test "invalid with unknown status" do
      attrs = Map.put(valid_attrs(), :status, "unknown")

      changeset = EnrollmentSchema.create_changeset(attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "validates valid statuses" do
      for status <- ~w(pending confirmed completed cancelled) do
        attrs = Map.put(valid_attrs(), :status, status)
        changeset = EnrollmentSchema.create_changeset(attrs)
        assert changeset.valid?, "Expected #{status} to be valid"
      end
    end

    test "invalid with unknown payment method" do
      attrs = Map.put(valid_attrs(), :payment_method, "bitcoin")

      changeset = EnrollmentSchema.create_changeset(attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).payment_method
    end

    test "validates valid payment methods" do
      for method <- ~w(card transfer) do
        attrs = Map.put(valid_attrs(), :payment_method, method)
        changeset = EnrollmentSchema.create_changeset(attrs)
        assert changeset.valid?, "Expected #{method} to be valid"
      end
    end

    test "allows nil payment method" do
      attrs = Map.put(valid_attrs(), :payment_method, nil)

      changeset = EnrollmentSchema.create_changeset(attrs)

      assert changeset.valid?
    end

    test "validates cancellation_reason max length" do
      attrs = Map.put(valid_attrs(), :cancellation_reason, String.duplicate("a", 1001))

      changeset = EnrollmentSchema.create_changeset(attrs)

      refute changeset.valid?
      assert "should be at most 1000 character(s)" in errors_on(changeset).cancellation_reason
    end

    test "validates special_requirements max length" do
      attrs = Map.put(valid_attrs(), :special_requirements, String.duplicate("a", 501))

      changeset = EnrollmentSchema.create_changeset(attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).special_requirements
    end

    test "validates amounts are non-negative" do
      for field <- [:subtotal, :vat_amount, :card_fee_amount, :total_amount] do
        attrs = Map.put(valid_attrs(), field, Decimal.new("-1.00"))
        changeset = EnrollmentSchema.create_changeset(attrs)
        refute changeset.valid?, "Expected #{field} to reject negative values"
        assert "must be greater than or equal to 0" in errors_on(changeset)[field]
      end
    end

    test "allows zero amounts" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          subtotal: Decimal.new("0"),
          vat_amount: Decimal.new("0"),
          card_fee_amount: Decimal.new("0"),
          total_amount: Decimal.new("0")
        })

      changeset = EnrollmentSchema.create_changeset(attrs)

      assert changeset.valid?
    end
  end

  describe "update_changeset/2" do
    test "allows updating status" do
      schema = %EnrollmentSchema{status: "pending"}
      attrs = %{status: "confirmed"}

      changeset = EnrollmentSchema.update_changeset(schema, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :status) == "confirmed"
    end

    test "does not allow changing program_id" do
      schema = %EnrollmentSchema{program_id: Ecto.UUID.generate()}
      new_program_id = Ecto.UUID.generate()
      attrs = %{program_id: new_program_id}

      changeset = EnrollmentSchema.update_changeset(schema, attrs)

      assert is_nil(Ecto.Changeset.get_change(changeset, :program_id))
    end

    test "does not allow changing child_id" do
      schema = %EnrollmentSchema{child_id: Ecto.UUID.generate()}
      new_child_id = Ecto.UUID.generate()
      attrs = %{child_id: new_child_id}

      changeset = EnrollmentSchema.update_changeset(schema, attrs)

      assert is_nil(Ecto.Changeset.get_change(changeset, :child_id))
    end

    test "does not allow changing parent_id" do
      schema = %EnrollmentSchema{parent_id: Ecto.UUID.generate()}
      new_parent_id = Ecto.UUID.generate()
      attrs = %{parent_id: new_parent_id}

      changeset = EnrollmentSchema.update_changeset(schema, attrs)

      assert is_nil(Ecto.Changeset.get_change(changeset, :parent_id))
    end

    test "allows updating optional fields" do
      schema = %EnrollmentSchema{}

      attrs = %{
        confirmed_at: DateTime.utc_now(),
        cancellation_reason: "Changed plans",
        special_requirements: "Needs wheelchair access"
      }

      changeset = EnrollmentSchema.update_changeset(schema, attrs)

      assert changeset.valid?
    end
  end

  defp valid_attrs do
    %{
      program_id: Ecto.UUID.generate(),
      child_id: Ecto.UUID.generate(),
      parent_id: Ecto.UUID.generate(),
      status: "pending",
      enrolled_at: DateTime.utc_now()
    }
  end
end

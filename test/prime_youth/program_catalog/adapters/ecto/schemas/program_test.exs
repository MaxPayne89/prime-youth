defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.ProgramTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        title: "Summer Soccer Camp",
        description: "Learn soccer fundamentals in a fun summer environment.",
        provider_id: Ecto.UUID.generate(),
        category: "sports",
        age_min: 8,
        age_max: 12,
        capacity: 20,
        current_enrollment: 0,
        price_amount: Decimal.new("250.00"),
        price_currency: "USD",
        price_unit: "program",
        has_discount: false,
        status: "draft",
        is_prime_youth: false
      }

      changeset = Program.changeset(%Program{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Program.changeset(%Program{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).provider_id
      assert "can't be blank" in errors_on(changeset).category
    end

    test "title validation" do
      attrs = valid_attrs()

      # Too short
      changeset = Program.changeset(%Program{}, Map.put(attrs, :title, "ab"))
      refute changeset.valid?
      assert "should be at least 3 character(s)" in errors_on(changeset).title

      # Too long
      changeset =
        Program.changeset(%Program{}, Map.put(attrs, :title, String.duplicate("a", 201)))

      refute changeset.valid?
      assert "should be at most 200 character(s)" in errors_on(changeset).title
    end

    test "description validation" do
      attrs = valid_attrs()

      # Too short
      changeset = Program.changeset(%Program{}, Map.put(attrs, :description, "short"))
      refute changeset.valid?
      assert "should be at least 10 character(s)" in errors_on(changeset).description

      # Too long
      changeset =
        Program.changeset(%Program{}, Map.put(attrs, :description, String.duplicate("a", 5001)))

      refute changeset.valid?
      assert "should be at most 5000 character(s)" in errors_on(changeset).description
    end

    test "category validation" do
      attrs = valid_attrs()

      valid_categories = [
        "sports",
        "arts",
        "stem",
        "language",
        "music",
        "academic",
        "outdoor",
        "cultural",
        "leadership",
        "creative_writing",
        "cooking",
        "other"
      ]

      for category <- valid_categories do
        changeset = Program.changeset(%Program{}, Map.put(attrs, :category, category))
        assert changeset.valid?, "Category #{category} should be valid"
      end

      changeset = Program.changeset(%Program{}, Map.put(attrs, :category, "invalid_category"))
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).category
    end

    test "age range validation" do
      attrs = valid_attrs()

      # age_min must be >= 0
      changeset = Program.changeset(%Program{}, Map.put(attrs, :age_min, -1))
      refute changeset.valid?

      # age_max must be >= age_min
      changeset = Program.changeset(%Program{}, Map.merge(attrs, %{age_min: 10, age_max: 8}))
      refute changeset.valid?
    end

    test "capacity validation" do
      attrs = valid_attrs()

      # Must be > 0
      changeset = Program.changeset(%Program{}, Map.put(attrs, :capacity, 0))
      refute changeset.valid?
    end

    test "current_enrollment validation" do
      attrs = valid_attrs()

      # Must be >= 0
      changeset = Program.changeset(%Program{}, Map.put(attrs, :current_enrollment, -1))
      refute changeset.valid?

      # Cannot exceed capacity
      changeset =
        Program.changeset(%Program{}, Map.merge(attrs, %{capacity: 10, current_enrollment: 15}))

      refute changeset.valid?
    end

    test "pricing validation" do
      attrs = valid_attrs()

      # price_amount must be >= 0
      changeset =
        Program.changeset(%Program{}, Map.put(attrs, :price_amount, Decimal.new("-10.00")))

      refute changeset.valid?

      # price_unit must be valid
      valid_units = ["session", "week", "month", "program"]

      for unit <- valid_units do
        changeset = Program.changeset(%Program{}, Map.put(attrs, :price_unit, unit))
        assert changeset.valid?, "Price unit #{unit} should be valid"
      end
    end

    test "discount validation" do
      attrs = valid_attrs()

      # If has_discount is true, discount_amount must be present
      changeset =
        Program.changeset(
          %Program{},
          Map.merge(attrs, %{has_discount: true, discount_amount: nil})
        )

      refute changeset.valid?

      # discount_amount must be < price_amount
      changeset =
        Program.changeset(
          %Program{},
          Map.merge(attrs, %{
            has_discount: true,
            price_amount: Decimal.new("100.00"),
            discount_amount: Decimal.new("150.00")
          })
        )

      refute changeset.valid?
    end

    test "status validation" do
      attrs = valid_attrs()

      valid_statuses = ["draft", "pending_approval", "approved", "rejected"]

      for status <- valid_statuses do
        changeset = Program.changeset(%Program{}, Map.put(attrs, :status, status))
        assert changeset.valid?, "Status #{status} should be valid"
      end
    end

    test "defaults" do
      attrs = %{
        title: "Test Program",
        description: "Test description for the program.",
        provider_id: Ecto.UUID.generate(),
        category: "sports",
        age_min: 8,
        age_max: 12,
        capacity: 20,
        price_amount: Decimal.new("100.00"),
        price_currency: "USD",
        price_unit: "session"
      }

      changeset = Program.changeset(%Program{}, attrs)
      assert changeset.valid?

      # Check defaults
      assert Ecto.Changeset.get_field(changeset, :current_enrollment) == 0
      assert Ecto.Changeset.get_field(changeset, :has_discount) == false
      assert Ecto.Changeset.get_field(changeset, :status) == "draft"
      assert Ecto.Changeset.get_field(changeset, :is_prime_youth) == false
      assert Ecto.Changeset.get_field(changeset, :featured) == false
    end
  end

  # Helper functions

  defp valid_attrs do
    %{
      title: "Summer Soccer Camp",
      description: "Learn soccer fundamentals in a fun summer environment.",
      provider_id: Ecto.UUID.generate(),
      category: "sports",
      age_min: 8,
      age_max: 12,
      capacity: 20,
      current_enrollment: 0,
      price_amount: Decimal.new("250.00"),
      price_currency: "USD",
      price_unit: "program",
      has_discount: false,
      status: "draft",
      is_prime_youth: false,
      featured: false
    }
  end
end

defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchemaTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        title: "Summer Soccer Camp",
        description: "Fun soccer activities for kids",
        schedule: "Mon-Fri 9AM-12PM",
        age_range: "6-12",
        price: Decimal.new("150.00"),
        pricing_period: "per week",
        spots_available: 20,
        gradient_class: "from-blue-500 to-purple-600",
        icon_path: "/images/soccer.svg"
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "valid changeset with minimum required fields (no gradient or icon)" do
      attrs = %{
        title: "Art Class",
        description: "Creative art activities",
        schedule: "Saturdays 10AM-12PM",
        age_range: "8-14",
        price: Decimal.new("75.00"),
        pricing_period: "per month",
        spots_available: 15
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "valid changeset with price = 0 (free program)" do
      attrs = %{
        title: "Community Day",
        description: "Free community event",
        schedule: "Sunday 2PM-5PM",
        age_range: "All ages",
        price: Decimal.new("0.00"),
        pricing_period: "per session",
        spots_available: 100
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :price) == Decimal.new("0.00")
    end

    test "valid changeset with spots_available = 0 (sold out)" do
      attrs = %{
        title: "Popular Camp",
        description: "Sold out camp",
        schedule: "All week",
        age_range: "10-15",
        price: Decimal.new("200.00"),
        pricing_period: "per week",
        spots_available: 0
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
      # Use get_field instead of get_change since 0 is the default value
      assert get_field(changeset, :spots_available) == 0
    end

    test "invalid changeset when title is missing" do
      attrs = %{
        description: "Description without title",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "invalid changeset when description is missing" do
      attrs = %{
        title: "Title without description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).description
    end

    test "invalid changeset when schedule is missing" do
      attrs = %{
        title: "Program",
        description: "Description",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).schedule
    end

    test "invalid changeset when age_range is missing" do
      attrs = %{
        title: "Program",
        description: "Description",
        schedule: "Mon-Fri",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).age_range
    end

    test "invalid changeset when price is missing" do
      attrs = %{
        title: "Program",
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).price
    end

    test "invalid changeset when pricing_period is missing" do
      attrs = %{
        title: "Program",
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).pricing_period
    end

    test "invalid changeset when title exceeds 100 characters" do
      long_title = String.duplicate("a", 101)

      attrs = %{
        title: long_title,
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).title
    end

    test "invalid changeset when description exceeds 500 characters" do
      long_description = String.duplicate("a", 501)

      attrs = %{
        title: "Program",
        description: long_description,
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).description
    end

    test "invalid changeset when price is negative" do
      attrs = %{
        title: "Program",
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("-10.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).price
    end

    test "invalid changeset when spots_available is negative" do
      attrs = %{
        title: "Program",
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: -5
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).spots_available
    end

    test "title at exactly 100 characters is valid" do
      title_100 = String.duplicate("a", 100)

      attrs = %{
        title: title_100,
        description: "Description",
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
    end

    test "description at exactly 500 characters is valid" do
      description_500 = String.duplicate("a", 500)

      attrs = %{
        title: "Program",
        description: description_500,
        schedule: "Mon-Fri",
        age_range: "6-12",
        price: Decimal.new("100.00"),
        pricing_period: "per week",
        spots_available: 10
      }

      changeset = ProgramSchema.changeset(%ProgramSchema{}, attrs)

      assert changeset.valid?
    end
  end
end

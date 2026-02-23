defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchemaSeasonTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema

  @valid_attrs %{
    title: "Ballsports & Parkour",
    description: "A fun sports program",
    category: "sports",
    age_range: "6-10",
    price: Decimal.new("120.00"),
    pricing_period: "semester"
  }

  describe "season field" do
    test "accepts season in changeset" do
      changeset =
        ProgramSchema.changeset(
          %ProgramSchema{},
          Map.put(@valid_attrs, :season, "Berlin International School 24/25: Semester 2")
        )

      assert changeset.valid?

      assert Ecto.Changeset.get_change(changeset, :season) ==
               "Berlin International School 24/25: Semester 2"
    end

    test "season is optional" do
      changeset = ProgramSchema.changeset(%ProgramSchema{}, @valid_attrs)

      assert changeset.valid?
      assert is_nil(Ecto.Changeset.get_change(changeset, :season))
    end

    test "validates season max length" do
      long_season = String.duplicate("a", 256)

      changeset =
        %ProgramSchema{}
        |> ProgramSchema.changeset(Map.put(@valid_attrs, :season, long_season))
        |> Map.put(:action, :validate)

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).season
    end
  end
end

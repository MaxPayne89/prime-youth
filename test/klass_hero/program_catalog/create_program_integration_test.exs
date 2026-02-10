defmodule KlassHero.ProgramCatalog.CreateProgramIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.IdentityFixtures
  alias KlassHero.ProgramCatalog

  describe "create_program/1" do
    test "creates program with required fields" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:ok, program} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Art Adventures",
                 description: "Creative art program for kids",
                 category: "arts",
                 price: Decimal.new("50.00")
               })

      assert program.title == "Art Adventures"
      assert program.category == "arts"
      assert program.instructor == nil
    end

    test "creates program with instructor" do
      provider = IdentityFixtures.provider_profile_fixture()
      staff = IdentityFixtures.staff_member_fixture(provider_id: provider.id)

      assert {:ok, program} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Soccer Camp",
                 description: "Learn to play soccer",
                 category: "sports",
                 price: Decimal.new("75.00"),
                 location: "Sports Park",
                 instructor_id: staff.id,
                 instructor_name: "#{staff.first_name} #{staff.last_name}",
                 instructor_headshot_url: staff.headshot_url
               })

      assert program.instructor != nil
      assert program.instructor.id == staff.id
      assert program.location == "Sports Park"
    end

    test "rejects missing required fields" do
      assert {:error, _changeset} =
               ProgramCatalog.create_program(%{title: "Incomplete"})
    end

    test "rejects invalid category" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:error, _changeset} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Test",
                 description: "Test desc",
                 category: "invalid_category",
                 price: Decimal.new("10.00")
               })
    end
  end
end

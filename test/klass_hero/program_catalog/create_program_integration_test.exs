defmodule KlassHero.ProgramCatalog.CreateProgramIntegrationTest do
  use KlassHero.DataCase

  import KlassHero.EventTestHelper

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

    test "rejects missing required fields with specific errors" do
      assert {:error, changeset} =
               ProgramCatalog.create_program(%{title: "Incomplete"})

      errors = errors_on(changeset)
      assert Map.has_key?(errors, :description)
      assert Map.has_key?(errors, :category)
      assert Map.has_key?(errors, :price)
      assert Map.has_key?(errors, :provider_id)
    end

    test "rejects negative price with specific error" do
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:error, changeset} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Bad Price Program",
                 description: "Has negative price",
                 category: "arts",
                 price: Decimal.new("-5.00")
               })

      errors = errors_on(changeset)
      assert "must be greater than or equal to 0" in errors[:price]
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

    test "accepts all valid program categories" do
      provider = IdentityFixtures.provider_profile_fixture()

      categories = ["sports", "arts", "music", "education", "life-skills", "camps", "workshops"]

      for category <- categories do
        assert {:ok, program} =
                 ProgramCatalog.create_program(%{
                   provider_id: provider.id,
                   title: "Program for #{category}",
                   description: "Testing #{category} category",
                   category: category,
                   price: Decimal.new("25.00")
                 })

        assert program.category == category
      end
    end

    test "dispatches program_created integration event on success" do
      setup_test_integration_events()
      provider = IdentityFixtures.provider_profile_fixture()

      assert {:ok, program} =
               ProgramCatalog.create_program(%{
                 provider_id: provider.id,
                 title: "Event Test Program",
                 description: "Tests event dispatch",
                 category: "arts",
                 price: Decimal.new("30.00")
               })

      event = assert_integration_event_published(:program_created)
      assert event.entity_id == program.id
      assert event.payload.provider_id == program.provider_id
      assert event.payload.title == "Event Test Program"
    end
  end
end

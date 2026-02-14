defmodule KlassHero.ProgramCatalog.UpdateProgramIntegrationTest do
  use KlassHero.DataCase

  alias KlassHero.ProgramCatalog
  alias KlassHero.ProviderFixtures

  describe "update_program/2" do
    setup do
      provider = ProviderFixtures.provider_profile_fixture()

      {:ok, program} =
        ProgramCatalog.create_program(%{
          provider_id: provider.id,
          title: "Original Title",
          description: "Original description",
          category: "sports",
          price: Decimal.new("100.00")
        })

      %{program: program}
    end

    test "updates title successfully", %{program: program} do
      assert {:ok, updated} =
               ProgramCatalog.update_program(program.id, %{title: "New Title"})

      assert updated.title == "New Title"
      assert updated.description == "Original description"
    end

    test "updates multiple fields", %{program: program} do
      assert {:ok, updated} =
               ProgramCatalog.update_program(program.id, %{
                 title: "Updated",
                 price: Decimal.new("200.00"),
                 spots_available: 15
               })

      assert updated.title == "Updated"
      assert updated.price == Decimal.new("200.00")
      assert updated.spots_available == 15
    end

    test "rejects invalid changes (empty title)", %{program: program} do
      assert {:error, _} = ProgramCatalog.update_program(program.id, %{title: ""})

      # Verify original unchanged
      assert {:ok, unchanged} = ProgramCatalog.get_program_by_id(program.id)
      assert unchanged.title == "Original Title"
    end

    test "returns not_found for invalid ID" do
      assert {:error, :not_found} =
               ProgramCatalog.update_program(Ecto.UUID.generate(), %{title: "New"})
    end

    test "repository returns stale_data on lock version conflict", %{program: program} do
      alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramRepository
      alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramSchema
      alias KlassHero.Repo

      # Simulate concurrent edit: bump lock_version in DB directly
      Repo.get!(ProgramSchema, program.id)
      |> Ecto.Changeset.change(%{})
      |> Ecto.Changeset.force_change(:lock_version, 99)
      |> Repo.update!()

      # The program struct still holds lock_version from creation (1).
      # Repository.update/1 sets lock_version=1 on the schema, but DB has 99.
      stale_program = %{program | title: "Stale Edit"}
      assert {:error, :stale_data} = ProgramRepository.update(stale_program)
    end
  end
end

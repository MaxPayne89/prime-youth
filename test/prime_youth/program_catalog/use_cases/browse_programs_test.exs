defmodule PrimeYouth.ProgramCatalog.UseCases.BrowseProgramsTest do
  use PrimeYouth.DataCase, async: true

  import PrimeYouth.ProgramCatalogFixtures

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program
  alias PrimeYouth.ProgramCatalog.UseCases.BrowsePrograms

  describe "execute/1" do
    setup do
      provider = provider_fixture()

      program1 =
        insert_program(provider, %{
          title: "Soccer Camp",
          category: "sports",
          age_min: 8,
          age_max: 12
        })

      program2 =
        insert_program(provider, %{
          title: "Art Workshop",
          category: "arts",
          age_min: 10,
          age_max: 14
        })

      program3 =
        insert_program(provider, %{title: "STEM Lab", category: "stem", age_min: 9, age_max: 13})

      {:ok, provider: provider, program1: program1, program2: program2, program3: program3}
    end

    test "returns all approved programs with no filters", %{
      program1: p1,
      program2: p2,
      program3: p3
    } do
      {:ok, programs} = BrowsePrograms.execute(%{})

      assert length(programs) == 3
      program_ids = Enum.map(programs, & &1.id)
      assert p1.id in program_ids
      assert p2.id in program_ids
      assert p3.id in program_ids
    end

    test "filters programs by category", %{program1: p1} do
      {:ok, programs} = BrowsePrograms.execute(%{category: "sports"})

      assert length(programs) == 1
      assert hd(programs).id == p1.id
    end

    test "filters programs by age range", %{program1: p1, program3: p3} do
      {:ok, programs} = BrowsePrograms.execute(%{age_min: 9, age_max: 9})

      assert length(programs) >= 2
      program_ids = Enum.map(programs, & &1.id)
      # 8-12 covers age 9
      assert p1.id in program_ids
      # 9-13 covers age 9
      assert p3.id in program_ids
    end

    test "filters programs by multiple criteria", %{program1: p1} do
      {:ok, programs} =
        BrowsePrograms.execute(%{
          category: "sports",
          age_min: 10,
          age_max: 10
        })

      assert length(programs) == 1
      assert hd(programs).id == p1.id
    end

    test "excludes draft programs" do
      provider = provider_fixture()
      _draft = insert_program(provider, %{title: "Draft Program", status: "draft"})

      {:ok, programs} = BrowsePrograms.execute(%{})

      draft_titles = Enum.map(programs, & &1.title)
      refute "Draft Program" in draft_titles
    end

    test "excludes pending approval programs" do
      provider = provider_fixture()
      _pending = insert_program(provider, %{title: "Pending Program", status: "pending_approval"})

      {:ok, programs} = BrowsePrograms.execute(%{})

      pending_titles = Enum.map(programs, & &1.title)
      refute "Pending Program" in pending_titles
    end

    test "includes only approved programs by default" do
      provider = provider_fixture()
      approved = insert_program(provider, %{title: "Approved Program", status: "approved"})

      {:ok, programs} = BrowsePrograms.execute(%{})

      program_ids = Enum.map(programs, & &1.id)
      assert approved.id in program_ids
    end

    test "excludes archived programs" do
      provider = provider_fixture()

      _archived =
        insert_program(provider, %{
          title: "Archived Program",
          archived_at: ~U[2025-01-01 12:00:00Z]
        })

      {:ok, programs} = BrowsePrograms.execute(%{})

      archived_titles = Enum.map(programs, & &1.title)
      refute "Archived Program" in archived_titles
    end

    test "returns empty list when no programs match filters" do
      {:ok, programs} = BrowsePrograms.execute(%{category: "nonexistent"})
      assert programs == []
    end

    test "returns programs with preloaded provider" do
      {:ok, programs} = BrowsePrograms.execute(%{})

      refute Enum.empty?(programs)
      first_program = hd(programs)
      assert first_program.provider != nil
      assert first_program.provider.name != nil
    end
  end

  # Helper functions

  defp insert_program(provider, attrs) do
    default_attrs = %{
      title: "Test Program",
      description: "A test program description that is long enough to pass validation.",
      provider_id: provider.id,
      category: "sports",
      age_min: 8,
      age_max: 12,
      capacity: 20,
      current_enrollment: 0,
      price_amount: Decimal.new("100.00"),
      price_currency: "USD",
      price_unit: "session",
      has_discount: false,
      status: "approved",
      is_prime_youth: false,
      featured: false
    }

    %Program{}
    |> Program.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end
end

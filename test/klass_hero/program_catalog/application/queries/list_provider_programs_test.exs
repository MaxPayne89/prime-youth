defmodule KlassHero.ProgramCatalog.Application.Queries.ListProviderProgramsTest do
  @moduledoc """
  Integration tests for the ListProviderPrograms use case.

  Tests the complete data flow: Use Case → Read Repository → Database → ProgramListing DTO.

  Test Coverage:
  - Returns programs for valid provider_id
  - Returns empty list when provider has no programs
  - Returns empty list for non-existent provider_id
  - Programs ordered by title
  - Handles single program
  - Handles free and premium variations
  """

  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Application.Queries.ListProviderPrograms
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo

  setup do
    Repo.delete_all(ProgramListingSchema)
    :ok
  end

  describe "execute/1" do
    test "returns programs for valid provider_id" do
      provider_id = Ecto.UUID.generate()

      insert_listing(%{
        title: "Soccer Stars",
        description: "Learn soccer fundamentals",
        category: "sports",
        age_range: "6-10 years",
        price: Decimal.new("150.00"),
        pricing_period: "per month",
        provider_id: provider_id
      })

      insert_listing(%{
        title: "Art Adventure",
        description: "Explore creativity",
        category: "arts",
        age_range: "7-12 years",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        provider_id: provider_id
      })

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2
      assert Enum.all?(programs, &match?(%ProgramListing{}, &1))

      titles = Enum.map(programs, & &1.title)
      assert "Soccer Stars" in titles
      assert "Art Adventure" in titles
    end

    test "returns empty list when provider has no programs" do
      provider_id = Ecto.UUID.generate()

      programs = ListProviderPrograms.execute(provider_id)

      assert programs == []
    end

    test "returns empty list for non-existent provider_id" do
      non_existent_provider = Ecto.UUID.generate()

      # Insert a program for a different provider
      insert_listing(%{
        title: "Other Program",
        provider_id: Ecto.UUID.generate()
      })

      programs = ListProviderPrograms.execute(non_existent_provider)

      assert programs == []
    end

    test "programs are ordered by title" do
      provider_id = Ecto.UUID.generate()

      insert_listing(%{title: "Zebra Club", provider_id: provider_id})
      insert_listing(%{title: "Art Class", provider_id: provider_id})
      insert_listing(%{title: "Music Camp", provider_id: provider_id})

      programs = ListProviderPrograms.execute(provider_id)

      titles = Enum.map(programs, & &1.title)
      assert titles == ["Art Class", "Music Camp", "Zebra Club"]
    end

    test "handles provider with single program" do
      provider_id = Ecto.UUID.generate()

      insert_listing(%{title: "Single Program", provider_id: provider_id})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 1
      assert List.first(programs).title == "Single Program"
    end

    test "programs include free and premium variations" do
      provider_id = Ecto.UUID.generate()

      insert_listing(%{
        title: "Community Event",
        price: Decimal.new("0.00"),
        pricing_period: "free",
        provider_id: provider_id
      })

      insert_listing(%{
        title: "Popular Camp",
        price: Decimal.new("500.00"),
        pricing_period: "per week",
        provider_id: provider_id
      })

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 2

      free = Enum.find(programs, &(&1.title == "Community Event"))
      assert Decimal.equal?(free.price, Decimal.new("0.00"))

      premium = Enum.find(programs, &(&1.title == "Popular Camp"))
      assert Decimal.equal?(premium.price, Decimal.new("500.00"))
    end

    test "does not return programs belonging to other providers" do
      provider_id = Ecto.UUID.generate()
      other_provider_id = Ecto.UUID.generate()

      insert_listing(%{title: "My Program", provider_id: provider_id})
      insert_listing(%{title: "Other Program", provider_id: other_provider_id})

      programs = ListProviderPrograms.execute(provider_id)

      assert length(programs) == 1
      assert List.first(programs).title == "My Program"
    end
  end

  defp insert_listing(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default_attrs = %{
      id: Ecto.UUID.generate(),
      title: "Default Program",
      category: "education",
      meeting_days: [],
      provider_id: Ecto.UUID.generate(),
      provider_verified: false,
      inserted_at: now,
      updated_at: now
    }

    merged = Map.merge(default_attrs, attrs)

    %ProgramListingSchema{}
    |> Ecto.Changeset.change(merged)
    |> Repo.insert!()
  end
end

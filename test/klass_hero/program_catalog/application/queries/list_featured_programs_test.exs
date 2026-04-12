defmodule KlassHero.ProgramCatalog.Application.Queries.ListFeaturedProgramsIntegrationTest do
  @moduledoc """
  Integration tests for the ListFeaturedPrograms use case.

  Verifies the COMPLETE data flow: Use Case → Read Repository → Database → ProgramListing DTO.
  """

  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Application.Queries.ListFeaturedPrograms
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo

  setup do
    Repo.delete_all(ProgramListingSchema)
    :ok
  end

  describe "execute/0" do
    test "returns first 2 programs when more exist" do
      insert_listing(%{title: "Art Class"})
      insert_listing(%{title: "Music Lessons"})
      insert_listing(%{title: "Soccer Camp"})

      result = ListFeaturedPrograms.execute()

      assert length(result) == 2
    end

    test "returns empty list when no programs exist" do
      result = ListFeaturedPrograms.execute()

      assert result == []
    end

    test "returns 1 program when only 1 exists" do
      insert_listing(%{title: "Art Class"})

      result = ListFeaturedPrograms.execute()

      assert length(result) == 1
      assert hd(result).title == "Art Class"
    end

    test "returns ProgramListing structs" do
      insert_listing(%{title: "Art Class"})
      insert_listing(%{title: "Soccer Camp"})

      result = ListFeaturedPrograms.execute()

      assert Enum.all?(result, &match?(%ProgramListing{}, &1))
    end

    test "excludes programs whose end_date is in the past" do
      insert_listing(%{title: "Expired Program", end_date: Date.add(Date.utc_today(), -1)})
      insert_listing(%{title: "Active Program", end_date: Date.add(Date.utc_today(), 7)})

      result = ListFeaturedPrograms.execute()

      titles = Enum.map(result, & &1.title)
      refute "Expired Program" in titles
      assert "Active Program" in titles
    end

    test "includes programs with nil end_date" do
      insert_listing(%{title: "Ongoing Program", end_date: nil})

      result = ListFeaturedPrograms.execute()

      titles = Enum.map(result, & &1.title)
      assert "Ongoing Program" in titles
    end
  end

  defp insert_listing(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default_attrs = %{
      id: Ecto.UUID.generate(),
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

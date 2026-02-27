defmodule KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepositoryTest do
  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Repositories.ProgramListingsRepository
  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Domain.ReadModels.ProgramListing
  alias KlassHero.Repo

  defp insert_listing(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      title: "Test Program",
      provider_id: Ecto.UUID.generate(),
      provider_verified: false,
      meeting_days: [],
      inserted_at: now,
      updated_at: now
    }

    merged = Map.merge(defaults, attrs)
    Repo.insert!(struct(ProgramListingSchema, merged))
  end

  describe "list_paginated/3" do
    test "returns programs as ProgramListing DTOs" do
      insert_listing(%{title: "Soccer Camp", category: "sports"})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, nil)

      assert [_ | _] = page.items
      assert Enum.all?(page.items, &match?(%ProgramListing{}, &1))
    end

    test "filters by category" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, "sports")

      titles = Enum.map(page.items, & &1.title)
      assert "Soccer" in titles
      refute "Math" in titles
    end

    test "returns all listings when category is nil" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, nil)

      titles = Enum.map(page.items, & &1.title)
      assert "Soccer" in titles
      assert "Math" in titles
    end

    test "paginates with cursor" do
      # Insert 3 listings with distinct timestamps so ordering is deterministic
      for i <- 1..3 do
        ts = DateTime.add(~U[2026-01-01 00:00:00Z], i, :second)
        insert_listing(%{title: "Program #{i}", inserted_at: ts, updated_at: ts})
      end

      {:ok, page1} = ProgramListingsRepository.list_paginated(2, nil, nil)
      assert length(page1.items) == 2
      assert page1.has_more == true
      assert page1.next_cursor != nil

      {:ok, page2} = ProgramListingsRepository.list_paginated(2, page1.next_cursor, nil)
      assert length(page2.items) == 1
      assert page2.has_more == false
    end

    test "returns error for invalid cursor" do
      assert {:error, :invalid_cursor} =
               ProgramListingsRepository.list_paginated(10, "bad-cursor", nil)
    end

    test "orders by inserted_at descending (newest first)" do
      old_ts = ~U[2026-01-01 00:00:00Z]
      new_ts = ~U[2026-01-02 00:00:00Z]

      insert_listing(%{title: "Old Program", inserted_at: old_ts, updated_at: old_ts})
      insert_listing(%{title: "New Program", inserted_at: new_ts, updated_at: new_ts})

      {:ok, page} = ProgramListingsRepository.list_paginated(10, nil, nil)

      titles = Enum.map(page.items, & &1.title)
      assert hd(titles) == "New Program"
    end
  end

  describe "get_by_id/1" do
    test "returns a ProgramListing for an existing id" do
      listing = insert_listing(%{title: "Art Class"})

      assert {:ok, %ProgramListing{title: "Art Class"}} =
               ProgramListingsRepository.get_by_id(listing.id)
    end

    test "returns :not_found for missing id" do
      assert {:error, :not_found} =
               ProgramListingsRepository.get_by_id(Ecto.UUID.generate())
    end

    test "returns :not_found for invalid uuid" do
      assert {:error, :not_found} =
               ProgramListingsRepository.get_by_id("not-a-uuid")
    end
  end

  describe "list_for_provider/1" do
    test "returns listings for a specific provider" do
      provider_id = Ecto.UUID.generate()
      insert_listing(%{title: "Provider Program", provider_id: provider_id})
      insert_listing(%{title: "Other Program", provider_id: Ecto.UUID.generate()})

      results = ProgramListingsRepository.list_for_provider(provider_id)

      assert length(results) == 1
      assert hd(results).title == "Provider Program"
      assert Enum.all?(results, &match?(%ProgramListing{}, &1))
    end

    test "returns empty list when provider has no programs" do
      results = ProgramListingsRepository.list_for_provider(Ecto.UUID.generate())

      assert results == []
    end

    test "orders by title ascending" do
      provider_id = Ecto.UUID.generate()
      insert_listing(%{title: "Zebra Club", provider_id: provider_id})
      insert_listing(%{title: "Art Class", provider_id: provider_id})

      results = ProgramListingsRepository.list_for_provider(provider_id)

      titles = Enum.map(results, & &1.title)
      assert titles == ["Art Class", "Zebra Club"]
    end
  end
end

defmodule KlassHero.ProgramCatalog.Application.UseCases.ListProgramsPaginatedIntegrationTest do
  @moduledoc """
  Integration tests for the ListProgramsPaginated use case.

  Verifies pagination, category filtering, and error handling through
  the real read repository.
  """

  use KlassHero.DataCase, async: false

  alias KlassHero.ProgramCatalog.Adapters.Driven.Persistence.Schemas.ProgramListingSchema
  alias KlassHero.ProgramCatalog.Application.UseCases.ListProgramsPaginated
  alias KlassHero.Repo

  setup do
    Repo.delete_all(ProgramListingSchema)
    :ok
  end

  describe "execute/2" do
    test "returns paginated results for first page" do
      for i <- 1..3 do
        ts = DateTime.add(~U[2026-01-01 00:00:00Z], i, :second)
        insert_listing(%{title: "Program #{i}", inserted_at: ts, updated_at: ts})
      end

      {:ok, page} = ListProgramsPaginated.execute(2, nil)

      assert length(page.items) == 2
      assert page.has_more == true
      assert page.next_cursor != nil
    end
  end

  describe "execute/3" do
    test "filters by valid category" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ListProgramsPaginated.execute(10, nil, "sports")

      titles = Enum.map(page.items, & &1.title)
      assert "Soccer" in titles
      refute "Math" in titles
    end

    test "invalid category defaults to all" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ListProgramsPaginated.execute(10, nil, "not-a-real-category")

      assert length(page.items) == 2
    end

    test "nil category returns all programs" do
      insert_listing(%{title: "Soccer", category: "sports"})
      insert_listing(%{title: "Math", category: "education"})

      {:ok, page} = ListProgramsPaginated.execute(10, nil, nil)

      assert length(page.items) == 2
    end

    test "returns error for invalid cursor" do
      assert {:error, :invalid_cursor} = ListProgramsPaginated.execute(10, "bad-cursor", nil)
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

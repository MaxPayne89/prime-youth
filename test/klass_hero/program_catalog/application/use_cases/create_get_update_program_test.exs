defmodule KlassHero.ProgramCatalog.Application.UseCases.CreateGetUpdateProgramTest do
  @moduledoc """
  Integration tests for CreateProgram, GetProgramById, and UpdateProgram use cases.

  Tests cover:
  - CreateProgram: success path, DB persistence, validation errors (missing title, invalid category)
  - GetProgramById: found, not found, invalid UUID
  - UpdateProgram: success path, DB persistence, not found
  """

  use KlassHero.DataCase, async: true

  alias KlassHero.ProgramCatalog
  alias KlassHero.ProgramCatalog.Application.UseCases.CreateProgram
  alias KlassHero.ProgramCatalog.Application.UseCases.GetProgramById
  alias KlassHero.ProgramCatalog.Application.UseCases.UpdateProgram
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        title: "Afternoon Soccer Camp #{System.unique_integer([:positive])}",
        description: "Fun soccer fundamentals for kids of all skill levels",
        category: "sports",
        price: Decimal.new("120.00"),
        pricing_period: "per month",
        provider_id: Ecto.UUID.generate(),
        age_range: "6-12 years"
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # CreateProgram
  # ---------------------------------------------------------------------------

  describe "CreateProgram.execute/1" do
    test "returns {:ok, program} with valid attributes" do
      attrs = valid_attrs()

      assert {:ok, program} = CreateProgram.execute(attrs)
      assert %Program{} = program
      assert program.title == attrs.title
      assert program.category == attrs.category
      assert program.provider_id == attrs.provider_id
    end

    test "assigns a UUID when no id is given" do
      attrs = valid_attrs()
      refute Map.has_key?(attrs, :id)

      assert {:ok, program} = CreateProgram.execute(attrs)
      assert is_binary(program.id)
      assert {:ok, _} = Ecto.UUID.cast(program.id)
    end

    test "persists the program so it can be fetched" do
      attrs = valid_attrs()

      assert {:ok, created} = CreateProgram.execute(attrs)
      assert {:ok, fetched} = GetProgramById.execute(created.id)
      assert fetched.id == created.id
      assert fetched.title == created.title
    end

    test "returns validation error list when title is missing" do
      attrs = valid_attrs(%{title: ""})

      assert {:error, errors} = CreateProgram.execute(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end

    test "returns validation error list when category is invalid" do
      attrs = valid_attrs(%{category: "not-a-real-category"})

      assert {:error, errors} = CreateProgram.execute(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "category"))
    end

    test "returns validation error list when provider_id is missing" do
      attrs = valid_attrs() |> Map.delete(:provider_id)

      assert {:error, errors} = CreateProgram.execute(attrs)
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "provider"))
    end
  end

  # ---------------------------------------------------------------------------
  # GetProgramById
  # ---------------------------------------------------------------------------

  describe "GetProgramById.execute/1" do
    test "returns {:ok, program} for an existing program" do
      attrs = valid_attrs()
      assert {:ok, created} = CreateProgram.execute(attrs)

      assert {:ok, program} = GetProgramById.execute(created.id)
      assert %Program{} = program
      assert program.id == created.id
      assert program.title == created.title
    end

    test "returns {:error, :not_found} for a non-existent UUID" do
      assert {:error, :not_found} = GetProgramById.execute(Ecto.UUID.generate())
    end

    test "returns {:error, :not_found} for an invalid UUID string" do
      assert {:error, :not_found} = GetProgramById.execute("not-a-uuid")
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateProgram
  # ---------------------------------------------------------------------------

  describe "UpdateProgram.execute/2" do
    test "updates allowed fields and returns {:ok, updated}" do
      attrs = valid_attrs()
      assert {:ok, created} = CreateProgram.execute(attrs)

      changes = %{description: "Updated description for the program"}
      assert {:ok, updated} = UpdateProgram.execute(created.id, changes)
      assert updated.description == "Updated description for the program"
      assert updated.id == created.id
    end

    test "persists changes to the database" do
      assert {:ok, created} = CreateProgram.execute(valid_attrs())

      changes = %{description: "Persisted description change"}
      assert {:ok, _} = UpdateProgram.execute(created.id, changes)

      assert {:ok, fetched} = GetProgramById.execute(created.id)
      assert fetched.description == "Persisted description change"
    end

    test "returns {:error, :not_found} for a non-existent program" do
      assert {:error, :not_found} =
               UpdateProgram.execute(Ecto.UUID.generate(), %{description: "irrelevant"})
    end

    test "returns validation error list when clearing the title" do
      assert {:ok, created} = CreateProgram.execute(valid_attrs())

      assert {:error, errors} = UpdateProgram.execute(created.id, %{title: ""})
      assert is_list(errors)
      assert Enum.any?(errors, &String.contains?(&1, "title"))
    end
  end

  # ---------------------------------------------------------------------------
  # ProgramCatalog context delegation
  # ---------------------------------------------------------------------------

  describe "ProgramCatalog context delegates" do
    test "create_program/1 delegates to CreateProgram use case" do
      attrs = valid_attrs()
      assert {:ok, %Program{}} = ProgramCatalog.create_program(attrs)
    end

    test "update_program/2 delegates to UpdateProgram use case" do
      assert {:ok, created} = ProgramCatalog.create_program(valid_attrs())

      assert {:ok, updated} = ProgramCatalog.update_program(created.id, %{description: "New desc"})
      assert updated.description == "New desc"
    end
  end
end

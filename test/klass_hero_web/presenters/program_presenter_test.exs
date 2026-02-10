defmodule KlassHeroWeb.Presenters.ProgramPresenterTest do
  use ExUnit.Case, async: true

  alias KlassHero.ProgramCatalog.Domain.Models.Instructor
  alias KlassHero.ProgramCatalog.Domain.Models.Program
  alias KlassHeroWeb.Presenters.ProgramPresenter

  describe "to_table_view/1" do
    test "program without instructor returns nil assigned_staff and placeholder fields" do
      program = build_program(%{instructor: nil})

      result = ProgramPresenter.to_table_view(program)

      assert result.assigned_staff == nil
      assert result.status == :active
      assert result.enrolled == 0
    end

    test "program with instructor populates assigned_staff" do
      instructor = %Instructor{
        id: "instr-1",
        name: "John Doe",
        headshot_url: "https://example.com/photo.jpg"
      }

      program = build_program(%{instructor: instructor})

      result = ProgramPresenter.to_table_view(program)

      assert result.assigned_staff.id == "instr-1"
      assert result.assigned_staff.name == "John Doe"
      assert result.assigned_staff.initials == "JD"
      assert result.assigned_staff.headshot_url == "https://example.com/photo.jpg"
    end

    test "converts Decimal price to integer" do
      program = build_program(%{price: Decimal.new("99.00")})

      result = ProgramPresenter.to_table_view(program)

      assert result.price == 99
    end

    test "builds two-letter initials from two-word name" do
      instructor = %Instructor{id: "1", name: "John Doe", headshot_url: nil}
      program = build_program(%{instructor: instructor})

      assert ProgramPresenter.to_table_view(program).assigned_staff.initials == "JD"
    end

    test "builds single-letter initial from single-word name" do
      instructor = %Instructor{id: "1", name: "Madonna", headshot_url: nil}
      program = build_program(%{instructor: instructor})

      assert ProgramPresenter.to_table_view(program).assigned_staff.initials == "M"
    end

    test "takes only first two initials from three-word name" do
      instructor = %Instructor{id: "1", name: "Mary Jane Watson", headshot_url: nil}
      program = build_program(%{instructor: instructor})

      assert ProgramPresenter.to_table_view(program).assigned_staff.initials == "MJ"
    end

    test "maps program id, name, category, and capacity" do
      program =
        build_program(%{
          id: "prog-1",
          title: "Summer Camp",
          category: "sports",
          spots_available: 25
        })

      result = ProgramPresenter.to_table_view(program)

      assert result.id == "prog-1"
      assert result.name == "Summer Camp"
      assert result.category == "Sports"
      assert result.capacity == 25
    end
  end

  describe "humanize_category/1" do
    test "explicit category mappings" do
      assert ProgramPresenter.humanize_category("arts") == "Arts"
      assert ProgramPresenter.humanize_category("education") == "Education"
      assert ProgramPresenter.humanize_category("sports") == "Sports"
      assert ProgramPresenter.humanize_category("music") == "Music"
    end

    test "fallback capitalizes unknown categories" do
      assert ProgramPresenter.humanize_category("life-skills") == "Life-skills"
      assert ProgramPresenter.humanize_category("camps") == "Camps"
      assert ProgramPresenter.humanize_category("workshops") == "Workshops"
    end

    test "nil returns General" do
      assert ProgramPresenter.humanize_category(nil) == "General"
    end
  end

  defp build_program(overrides) do
    defaults = %{
      id: "test-id",
      title: "Test Program",
      description: "A test program",
      category: "arts",
      price: Decimal.new("50.00"),
      spots_available: 10,
      instructor: nil
    }

    struct!(Program, Map.merge(defaults, overrides))
  end
end

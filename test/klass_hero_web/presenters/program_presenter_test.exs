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

    test "formats integer Decimal price as string" do
      program = build_program(%{price: Decimal.new("99.00")})

      result = ProgramPresenter.to_table_view(program)

      assert result.price == "99.00"
    end

    test "formats fractional Decimal price as string" do
      program = build_program(%{price: Decimal.new("29.99")})

      result = ProgramPresenter.to_table_view(program)

      assert result.price == "29.99"
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

  describe "format_schedule/1" do
    test "formats full schedule with days, times, and dates" do
      program =
        build_program(%{
          meeting_days: ["Monday", "Wednesday"],
          meeting_start_time: ~T[16:00:00],
          meeting_end_time: ~T[17:30:00],
          start_date: ~D[2026-03-01],
          end_date: ~D[2026-06-30]
        })

      result = ProgramPresenter.format_schedule(program)
      assert result.days == "Mon & Wed"
      assert result.times == "4:00 - 5:30 PM"
      assert result.date_range =~ "Mar 1"
      assert result.date_range =~ "Jun 30"
    end

    test "returns nil when no scheduling data" do
      program = build_program(%{meeting_days: [], meeting_start_time: nil})
      assert ProgramPresenter.format_schedule(program) == nil
    end

    test "formats single day" do
      program = build_program(%{meeting_days: ["Saturday"]})
      result = ProgramPresenter.format_schedule(program)
      assert result.days == "Sat"
    end

    test "formats three days with ampersand" do
      program = build_program(%{meeting_days: ["Monday", "Wednesday", "Friday"]})
      result = ProgramPresenter.format_schedule(program)
      assert result.days == "Mon, Wed & Fri"
    end

    test "formats days only when no times set" do
      program =
        build_program(%{
          meeting_days: ["Monday", "Wednesday"],
          meeting_start_time: nil,
          meeting_end_time: nil
        })

      result = ProgramPresenter.format_schedule(program)
      assert result.days == "Mon & Wed"
      assert result.times == nil
    end

    test "formats times crossing AM/PM" do
      program =
        build_program(%{
          meeting_days: ["Saturday"],
          meeting_start_time: ~T[11:00:00],
          meeting_end_time: ~T[13:30:00]
        })

      result = ProgramPresenter.format_schedule(program)
      assert result.times == "11:00 AM - 1:30 PM"
    end
  end

  describe "format_schedule_brief/1" do
    test "formats days and times from a map" do
      program = %{
        meeting_days: ["Monday", "Wednesday"],
        meeting_start_time: ~T[16:00:00],
        meeting_end_time: ~T[17:30:00]
      }

      result = ProgramPresenter.format_schedule_brief(program)
      assert result == "Mon & Wed 4:00 - 5:30 PM"
    end

    test "formats days only when no times" do
      program = %{meeting_days: ["Saturday"]}
      result = ProgramPresenter.format_schedule_brief(program)
      assert result == "Sat"
    end

    test "formats times only when no days" do
      program = %{
        meeting_start_time: ~T[09:00:00],
        meeting_end_time: ~T[11:00:00]
      }

      result = ProgramPresenter.format_schedule_brief(program)
      assert result == "9:00 - 11:00 AM"
    end

    test "returns empty string when no scheduling data" do
      result = ProgramPresenter.format_schedule_brief(%{})
      assert result == ""
    end

    test "works with domain struct" do
      program =
        build_program(%{
          meeting_days: ["Tuesday", "Thursday"],
          meeting_start_time: ~T[14:00:00],
          meeting_end_time: ~T[15:00:00]
        })

      result = ProgramPresenter.format_schedule_brief(program)
      assert result == "Tue & Thu 2:00 - 3:00 PM"
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
      instructor: nil,
      meeting_days: [],
      meeting_start_time: nil,
      meeting_end_time: nil,
      start_date: nil,
      end_date: nil
    }

    struct!(Program, Map.merge(defaults, overrides))
  end
end

defmodule PrimeYouth.ProgramCatalog.Domain.Entities.ProgramScheduleTest do
  use ExUnit.Case, async: true

  alias PrimeYouth.ProgramCatalog.Domain.Entities.ProgramSchedule

  describe "new/1" do
    test "creates schedule with valid attributes" do
      attrs = %{
        id: Ecto.UUID.generate(),
        program_id: Ecto.UUID.generate(),
        start_date: ~D[2025-06-01],
        end_date: ~D[2025-08-15],
        days_of_week: ["monday", "wednesday", "friday"],
        start_time: ~T[09:00:00],
        end_time: ~T[12:00:00],
        recurrence_pattern: "weekly",
        session_count: 24,
        session_duration: 180
      }

      assert {:ok, %ProgramSchedule{} = schedule} = ProgramSchedule.new(attrs)
      assert schedule.start_date == ~D[2025-06-01]
      assert schedule.end_date == ~D[2025-08-15]
      assert schedule.days_of_week == ["monday", "wednesday", "friday"]
      assert schedule.recurrence_pattern == "weekly"
      assert schedule.session_count == 24
    end

    test "requires program_id" do
      attrs = valid_attrs() |> Map.delete(:program_id)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).program_id
    end

    test "requires start_date" do
      attrs = valid_attrs() |> Map.delete(:start_date)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).start_date
    end

    test "requires end_date" do
      attrs = valid_attrs() |> Map.delete(:end_date)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).end_date
    end

    test "end_date must be >= start_date" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_date: ~D[2025-06-15],
          end_date: ~D[2025-06-10]
        })

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "must be on or after start date" in errors_on(changeset).end_date
    end

    test "end_date can equal start_date (single day program)" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_date: ~D[2025-06-15],
          end_date: ~D[2025-06-15],
          recurrence_pattern: "once"
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert schedule.start_date == schedule.end_date
    end

    test "requires start_time" do
      attrs = valid_attrs() |> Map.delete(:start_time)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).start_time
    end

    test "requires end_time" do
      attrs = valid_attrs() |> Map.delete(:end_time)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).end_time
    end

    test "end_time must be > start_time" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_time: ~T[14:00:00],
          end_time: ~T[12:00:00]
        })

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "must be after start time" in errors_on(changeset).end_time
    end

    test "end_time cannot equal start_time" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_time: ~T[12:00:00],
          end_time: ~T[12:00:00]
        })

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "must be after start time" in errors_on(changeset).end_time
    end

    test "requires days_of_week" do
      attrs = valid_attrs() |> Map.delete(:days_of_week)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).days_of_week
    end

    test "days_of_week must contain valid day names" do
      attrs = valid_attrs()

      # Invalid day name
      assert {:error, changeset} =
               ProgramSchedule.new(Map.put(attrs, :days_of_week, ["invalid_day"]))

      assert "contains invalid day names" in errors_on(changeset).days_of_week

      # Mix of valid and invalid
      assert {:error, changeset} =
               ProgramSchedule.new(Map.put(attrs, :days_of_week, ["monday", "fake_day"]))

      assert "contains invalid day names" in errors_on(changeset).days_of_week
    end

    test "days_of_week accepts all valid day names" do
      attrs = valid_attrs()

      valid_days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

      assert {:ok, schedule} = ProgramSchedule.new(Map.put(attrs, :days_of_week, valid_days))
      assert schedule.days_of_week == valid_days
    end

    test "requires recurrence_pattern" do
      attrs = valid_attrs() |> Map.delete(:recurrence_pattern)

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "can't be blank" in errors_on(changeset).recurrence_pattern
    end

    test "recurrence_pattern must be valid value" do
      attrs = valid_attrs()

      assert {:error, changeset} =
               ProgramSchedule.new(Map.put(attrs, :recurrence_pattern, "invalid"))

      assert "is invalid" in errors_on(changeset).recurrence_pattern
    end

    test "recurrence_pattern accepts valid values" do
      attrs = valid_attrs()

      for pattern <- ["once", "daily", "weekly", "seasonal"] do
        assert {:ok, schedule} = ProgramSchedule.new(Map.put(attrs, :recurrence_pattern, pattern))
        assert schedule.recurrence_pattern == pattern
      end
    end

    test "session_count required for recurring patterns" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "weekly",
          session_count: nil
        })

      assert {:error, changeset} = ProgramSchedule.new(attrs)
      assert "is required for recurring programs" in errors_on(changeset).session_count
    end

    test "session_count optional for one-time programs" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "once",
          session_count: nil
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert is_nil(schedule.session_count)
    end

    test "session_count must be positive when provided" do
      attrs = valid_attrs()

      assert {:error, changeset} = ProgramSchedule.new(Map.put(attrs, :session_count, 0))
      assert "must be greater than 0" in errors_on(changeset).session_count

      assert {:error, changeset} = ProgramSchedule.new(Map.put(attrs, :session_count, -5))
      assert "must be greater than 0" in errors_on(changeset).session_count
    end

    test "session_duration must be positive when provided" do
      attrs = valid_attrs()

      assert {:error, changeset} = ProgramSchedule.new(Map.put(attrs, :session_duration, 0))
      assert "must be greater than 0" in errors_on(changeset).session_duration

      assert {:error, changeset} = ProgramSchedule.new(Map.put(attrs, :session_duration, -30))
      assert "must be greater than 0" in errors_on(changeset).session_duration
    end
  end

  describe "business rules" do
    test "weekly recurring schedule" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "weekly",
          days_of_week: ["monday", "wednesday", "friday"],
          session_count: 36
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert schedule.recurrence_pattern == "weekly"
      assert length(schedule.days_of_week) == 3
      assert schedule.session_count == 36
    end

    test "daily recurring schedule" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "daily",
          days_of_week: ["monday", "tuesday", "wednesday", "thursday", "friday"],
          session_count: 60
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert schedule.recurrence_pattern == "daily"
    end

    test "seasonal program with flexible scheduling" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "seasonal",
          session_count: 12
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert schedule.recurrence_pattern == "seasonal"
    end

    test "one-time event" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_date: ~D[2025-07-04],
          end_date: ~D[2025-07-04],
          recurrence_pattern: "once",
          session_count: nil,
          days_of_week: ["saturday"]
        })

      assert {:ok, schedule} = ProgramSchedule.new(attrs)
      assert schedule.recurrence_pattern == "once"
      assert is_nil(schedule.session_count)
    end
  end

  # Helper functions

  defp valid_attrs do
    %{
      id: Ecto.UUID.generate(),
      program_id: Ecto.UUID.generate(),
      start_date: ~D[2025-06-01],
      end_date: ~D[2025-08-15],
      days_of_week: ["monday", "wednesday", "friday"],
      start_time: ~T[09:00:00],
      end_time: ~T[12:00:00],
      recurrence_pattern: "weekly",
      session_count: 24,
      session_duration: 180
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

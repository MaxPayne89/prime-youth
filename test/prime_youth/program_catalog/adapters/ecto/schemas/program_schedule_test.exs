defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.ProgramScheduleTest do
  use PrimeYouth.DataCase, async: true

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.ProgramSchedule

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
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

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).program_id
      assert "can't be blank" in errors_on(changeset).start_date
      assert "can't be blank" in errors_on(changeset).end_date
    end

    test "end_date must be >= start_date" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_date: ~D[2025-06-15],
          end_date: ~D[2025-06-10]
        })

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, attrs)
      refute changeset.valid?
    end

    test "end_time must be > start_time" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          start_time: ~T[14:00:00],
          end_time: ~T[12:00:00]
        })

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, attrs)
      refute changeset.valid?
    end

    test "days_of_week must contain valid day names" do
      attrs = valid_attrs()

      # Invalid day name
      changeset =
        ProgramSchedule.changeset(
          %ProgramSchedule{},
          Map.put(attrs, :days_of_week, ["invalid_day"])
        )

      refute changeset.valid?

      # Mix of valid and invalid
      changeset =
        ProgramSchedule.changeset(
          %ProgramSchedule{},
          Map.put(attrs, :days_of_week, ["monday", "fake_day"])
        )

      refute changeset.valid?
    end

    test "days_of_week accepts all valid day names" do
      attrs = valid_attrs()
      valid_days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

      changeset =
        ProgramSchedule.changeset(%ProgramSchedule{}, Map.put(attrs, :days_of_week, valid_days))

      assert changeset.valid?
    end

    test "recurrence_pattern must be valid value" do
      attrs = valid_attrs()

      changeset =
        ProgramSchedule.changeset(
          %ProgramSchedule{},
          Map.put(attrs, :recurrence_pattern, "invalid")
        )

      refute changeset.valid?
    end

    test "recurrence_pattern accepts valid values" do
      attrs = valid_attrs()

      for pattern <- ["once", "daily", "weekly", "seasonal"] do
        changeset =
          ProgramSchedule.changeset(
            %ProgramSchedule{},
            Map.put(attrs, :recurrence_pattern, pattern)
          )

        assert changeset.valid?
      end
    end

    test "session_count required for recurring patterns" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "weekly",
          session_count: nil
        })

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, attrs)
      refute changeset.valid?
    end

    test "session_count optional for one-time programs" do
      attrs =
        valid_attrs()
        |> Map.merge(%{
          recurrence_pattern: "once",
          session_count: nil
        })

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, attrs)
      assert changeset.valid?
    end

    test "session_count must be positive when provided" do
      attrs = valid_attrs()

      changeset = ProgramSchedule.changeset(%ProgramSchedule{}, Map.put(attrs, :session_count, 0))
      refute changeset.valid?

      changeset =
        ProgramSchedule.changeset(%ProgramSchedule{}, Map.put(attrs, :session_count, -5))

      refute changeset.valid?
    end
  end

  # Helper functions

  defp valid_attrs do
    %{
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

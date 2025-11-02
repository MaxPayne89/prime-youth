defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.ProgramSchedule do
  @moduledoc """
  Ecto schema for ProgramSchedule entity persistence.

  This is the infrastructure adapter that maps the ProgramSchedule domain entity to database tables.
  Handles various recurrence patterns and session management.

  ## Associations

  - `belongs_to :program` - Associated program (Program)

  ## Business Rules

  - end_date must be >= start_date
  - end_time must be > start_time
  - Recurring programs require session_count
  - days_of_week must contain valid day names
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "program_schedules" do
    field :start_date, :date
    field :end_date, :date
    field :days_of_week, {:array, :string}
    field :start_time, :time
    field :end_time, :time
    field :recurrence_pattern, :string
    field :session_count, :integer
    field :session_duration, :integer

    belongs_to :program, Program

    timestamps(type: :utc_datetime)
  end

  @valid_days_of_week ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
  @valid_recurrence_patterns ["once", "daily", "weekly", "seasonal"]

  @doc """
  Changeset for creating or updating a program schedule.

  Validates dates, times, recurrence patterns, and session requirements.

  ## Required Fields

  - start_date, end_date, days_of_week
  - start_time, end_time
  - recurrence_pattern, program_id

  ## Conditional Requirements

  **Recurring programs** (recurrence_pattern != "once"):
  - session_count (required)

  ## Optional Fields

  - session_duration

  ## Validations

  - start_date: must be valid date
  - end_date: must be >= start_date
  - start_time: must be valid time
  - end_time: must be > start_time
  - days_of_week: must be non-empty array of valid day names
  - recurrence_pattern: must be one of valid patterns
  - session_count: must be > 0 (if provided)
  - session_duration: must be > 0 (if provided)
  """
  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :start_date,
      :end_date,
      :days_of_week,
      :start_time,
      :end_time,
      :recurrence_pattern,
      :session_count,
      :session_duration,
      :program_id
    ])
    |> validate_required([
      :start_date,
      :end_date,
      :days_of_week,
      :start_time,
      :end_time,
      :recurrence_pattern
    ])
    |> validate_required_program_id()
    |> validate_inclusion(:recurrence_pattern, @valid_recurrence_patterns)
    |> validate_number(:session_count, greater_than: 0)
    |> validate_number(:session_duration, greater_than: 0)
    |> validate_date_range()
    |> validate_time_range()
    |> validate_days_of_week()
    |> validate_session_requirements()
    |> foreign_key_constraint(:program_id)
  end

  defp validate_required_program_id(changeset) do
    # Only validate program_id as required if it's being passed in attrs
    # When using cast_assoc, program_id is set automatically and won't be in attrs
    if Map.has_key?(changeset.params, "program_id") do
      validate_required(changeset, [:program_id])
    else
      changeset
    end
  end

  # Private validation helpers

  defp validate_date_range(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(end_date, start_date) == :lt do
      add_error(changeset, :end_date, "must be on or after start_date")
    else
      changeset
    end
  end

  defp validate_time_range(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && Time.compare(end_time, start_time) != :gt do
      add_error(changeset, :end_time, "must be after start_time")
    else
      changeset
    end
  end

  defp validate_days_of_week(changeset) do
    case get_field(changeset, :days_of_week) do
      nil ->
        changeset

      [] ->
        add_error(changeset, :days_of_week, "cannot be empty")

      days when is_list(days) ->
        invalid_days = Enum.filter(days, &(&1 not in @valid_days_of_week))

        if Enum.empty?(invalid_days) do
          changeset
        else
          add_error(
            changeset,
            :days_of_week,
            "contains invalid day names: #{Enum.join(invalid_days, ", ")}"
          )
        end

      _ ->
        add_error(changeset, :days_of_week, "must be a list of day names")
    end
  end

  defp validate_session_requirements(changeset) do
    recurrence_pattern = get_field(changeset, :recurrence_pattern)
    session_count = get_field(changeset, :session_count)

    # Recurring programs require session_count
    if recurrence_pattern in ["daily", "weekly", "seasonal"] && is_nil(session_count) do
      add_error(changeset, :session_count, "is required for recurring programs")
    else
      changeset
    end
  end
end

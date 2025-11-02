defmodule PrimeYouth.ProgramCatalog.Domain.Entities.ProgramSchedule do
  @moduledoc """
  ProgramSchedule domain entity representing timing and availability of a program.

  This is a pure Elixir struct that encapsulates scheduling business logic without
  infrastructure concerns. Supports various recurrence patterns and session management.

  ## Business Rules

  - `end_date` must be >= `start_date`
  - `end_time` must be > `start_time`
  - For recurring programs, `session_count` is required
  - `days_of_week` must contain valid day names
  - Seasonal programs use recurrence_pattern "seasonal" and may have flexible scheduling
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          program_id: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          days_of_week: [String.t()],
          start_time: Time.t(),
          end_time: Time.t(),
          recurrence_pattern: String.t(),
          session_count: non_neg_integer() | nil,
          session_duration: non_neg_integer() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:program_id, :start_date, :end_date, :days_of_week, :start_time, :end_time, :recurrence_pattern]

  defstruct [
    :id,
    :program_id,
    :start_date,
    :end_date,
    :days_of_week,
    :start_time,
    :end_time,
    :recurrence_pattern,
    :session_count,
    :session_duration,
    :created_at,
    :updated_at
  ]

  @valid_days_of_week ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
  @valid_recurrence_patterns ["once", "daily", "weekly", "seasonal"]

  @doc """
  Creates a new ProgramSchedule entity with validation.

  ## Parameters

  - `attrs`: Map of schedule attributes

  ## Returns

  - `{:ok, %ProgramSchedule{}}` if valid
  - `{:error, reason}` if validation fails

  ## Examples

      # Single session program
      iex> PrimeYouth.ProgramCatalog.Domain.Entities.ProgramSchedule.new(%{
      ...>   program_id: "program-uuid",
      ...>   start_date: ~D[2025-06-01],
      ...>   end_date: ~D[2025-06-01],
      ...>   start_time: ~T[09:00:00],
      ...>   end_time: ~T[12:00:00],
      ...>   days_of_week: ["monday"],
      ...>   recurrence_pattern: "once"
      ...> })
      {:ok, %ProgramSchedule{}}

      # Weekly recurring program
      iex> PrimeYouth.ProgramCatalog.Domain.Entities.ProgramSchedule.new(%{
      ...>   program_id: "program-uuid",
      ...>   start_date: ~D[2025-06-01],
      ...>   end_date: ~D[2025-08-31],
      ...>   start_time: ~T[14:00:00],
      ...>   end_time: ~T[16:00:00],
      ...>   days_of_week: ["monday", "wednesday", "friday"],
      ...>   recurrence_pattern: "weekly",
      ...>   session_count: 36
      ...> })
      {:ok, %ProgramSchedule{}}

  """
  def new(attrs) when is_map(attrs) do
    with {:ok, attrs} <- validate_required_fields(attrs),
         {:ok, attrs} <- validate_dates(attrs),
         {:ok, attrs} <- validate_times(attrs),
         {:ok, attrs} <- validate_days_of_week(attrs),
         {:ok, attrs} <- validate_recurrence_pattern(attrs),
         {:ok, attrs} <- validate_session_requirements(attrs) do
      schedule = struct(__MODULE__, attrs)
      {:ok, schedule}
    end
  end

  @doc """
  Checks if this is a one-time program (single session).
  """
  def one_time?(%__MODULE__{recurrence_pattern: "once"}) do
    true
  end

  def one_time?(%__MODULE__{}), do: false

  @doc """
  Checks if this is a recurring program (multiple sessions).
  """
  def recurring?(%__MODULE__{} = schedule) do
    not one_time?(schedule)
  end

  @doc """
  Calculates the total duration in minutes for a single session.
  """
  def session_duration_minutes(%__MODULE__{start_time: start_time, end_time: end_time}) do
    Time.diff(end_time, start_time, :minute)
  end

  @doc """
  Formats the schedule for display.

  Returns a human-readable string describing when the program runs.
  """
  def format_schedule(%__MODULE__{recurrence_pattern: "once"} = schedule) do
    "#{Date.to_string(schedule.start_date)} from #{Time.to_string(schedule.start_time)} to #{Time.to_string(schedule.end_time)}"
  end

  def format_schedule(%__MODULE__{} = schedule) do
    days =
      schedule.days_of_week
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(", ")

    times = "#{Time.to_string(schedule.start_time)} - #{Time.to_string(schedule.end_time)}"

    session_info =
      case schedule.session_count do
        nil -> ""
        count -> " (#{count} sessions)"
      end

    "#{days}, #{times}#{session_info}"
  end

  # Private validation functions

  defp validate_required_fields(attrs) do
    required = [
      :program_id,
      :start_date,
      :end_date,
      :days_of_week,
      :start_time,
      :end_time,
      :recurrence_pattern
    ]

    missing =
      Enum.filter(required, fn field ->
        not Map.has_key?(attrs, field) or is_nil(Map.get(attrs, field))
      end)

    if Enum.empty?(missing) do
      {:ok, attrs}
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_dates(%{start_date: start_date, end_date: end_date} = attrs) do
    cond do
      not match?(%Date{}, start_date) ->
        {:error, :invalid_start_date}

      not match?(%Date{}, end_date) ->
        {:error, :invalid_end_date}

      Date.compare(end_date, start_date) == :lt ->
        {:error, :end_date_before_start_date}

      true ->
        {:ok, attrs}
    end
  end

  defp validate_dates(_), do: {:error, :invalid_dates}

  defp validate_times(%{start_time: start_time, end_time: end_time} = attrs) do
    cond do
      not match?(%Time{}, start_time) ->
        {:error, :invalid_start_time}

      not match?(%Time{}, end_time) ->
        {:error, :invalid_end_time}

      Time.compare(end_time, start_time) != :gt ->
        {:error, :end_time_not_after_start_time}

      true ->
        {:ok, attrs}
    end
  end

  defp validate_times(_), do: {:error, :invalid_times}

  defp validate_days_of_week(%{days_of_week: days} = attrs) when is_list(days) do
    cond do
      Enum.empty?(days) ->
        {:error, :empty_days_of_week}

      not Enum.all?(days, &(&1 in @valid_days_of_week)) ->
        invalid_days = Enum.filter(days, &(&1 not in @valid_days_of_week))
        {:error, {:invalid_days_of_week, invalid_days}}

      true ->
        {:ok, attrs}
    end
  end

  defp validate_days_of_week(_), do: {:error, :invalid_days_of_week}

  defp validate_recurrence_pattern(%{recurrence_pattern: pattern} = attrs)
       when is_binary(pattern) do
    if pattern in @valid_recurrence_patterns do
      {:ok, attrs}
    else
      {:error, {:invalid_recurrence_pattern, pattern}}
    end
  end

  defp validate_recurrence_pattern(_), do: {:error, :invalid_recurrence_pattern}

  defp validate_session_requirements(%{recurrence_pattern: "once"} = attrs) do
    # One-time programs don't need session_count
    {:ok, attrs}
  end

  defp validate_session_requirements(%{recurrence_pattern: pattern, session_count: count} = attrs)
       when pattern in ["daily", "weekly", "seasonal"] do
    cond do
      is_nil(count) ->
        {:error, :session_count_required_for_recurring}

      not is_integer(count) ->
        {:error, :invalid_session_count}

      count <= 0 ->
        {:error, :session_count_must_be_positive}

      true ->
        {:ok, attrs}
    end
  end

  defp validate_session_requirements(_) do
    {:error, :session_count_required_for_recurring}
  end
end

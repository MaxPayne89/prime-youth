defmodule KlassHeroWeb.Presenters.ProgramPresenter do
  @moduledoc """
  Presentation layer for transforming Program domain models to UI-ready formats.

  This module follows the DDD/Ports & Adapters pattern by keeping presentation
  concerns in the web layer while the domain model stays pure.

  ## Usage

      alias KlassHeroWeb.Presenters.ProgramPresenter

      # For table views (provider dashboard)
      programs_for_view = Enum.map(programs, &ProgramPresenter.to_table_view/1)
  """

  use Gettext, backend: KlassHeroWeb.Gettext

  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @doc """
  Transforms a Program domain model to table view format.

  Used for the provider dashboard program inventory table.

  Returns a map with: id, name, category, price, assigned_staff, status, enrolled, capacity

  ## Placeholder Values

  The following fields return placeholder values pending feature implementation:

  - `status: :active` - Program status tracking not yet implemented
  - `enrolled: 0` - Enrollment count integration not yet implemented

  These placeholders ensure the UI can render properly while the underlying
  features are developed in future iterations.
  """
  @spec to_table_view(Program.t()) :: map()
  def to_table_view(%Program{} = program) do
    %{
      id: program.id,
      name: program.title,
      category: humanize_category(program.category),
      # Trigger: price is a Decimal that may have fractional cents (e.g., 29.99)
      # Why: Decimal.to_integer crashes on non-integer values; to_string preserves precision
      # Outcome: price rendered as "29.99" in template's €{program.price} display
      price: program.price |> Decimal.round(2) |> Decimal.to_string(),
      assigned_staff: format_instructor(program.instructor),
      # Placeholder: Program status tracking pending implementation
      status: :active,
      # Placeholder: Enrollment count integration pending implementation
      enrolled: 0,
      capacity: program.spots_available
    }
  end

  @day_abbreviations %{
    "Monday" => "Mon",
    "Tuesday" => "Tue",
    "Wednesday" => "Wed",
    "Thursday" => "Thu",
    "Friday" => "Fri",
    "Saturday" => "Sat",
    "Sunday" => "Sun"
  }

  @doc """
  Formats a program's scheduling fields for display.

  Returns a map with :days, :times, :date_range keys, or nil if no scheduling data.
  """
  @spec format_schedule(Program.t()) ::
          %{days: String.t() | nil, times: String.t() | nil, date_range: String.t() | nil} | nil
  def format_schedule(%Program{meeting_days: days} = program) when days == [] or is_nil(days) do
    # Trigger: no meeting days provided
    # Why: if there's also no start time and no date range, there's nothing to display
    # Outcome: returns nil so UI can hide the schedule section entirely
    if !(is_nil(program.meeting_start_time) and is_nil(program.start_date)) do
      %{
        days: nil,
        times: format_times(program.meeting_start_time, program.meeting_end_time),
        date_range: format_date_range(program.start_date, program.end_date)
      }
    end
  end

  def format_schedule(%Program{} = program) do
    %{
      days: format_days(program.meeting_days),
      times: format_times(program.meeting_start_time, program.meeting_end_time),
      date_range: format_date_range(program.start_date, program.end_date)
    }
  end

  defp format_days([day]), do: Map.get(@day_abbreviations, day, day)

  defp format_days([d1, d2]) do
    "#{Map.get(@day_abbreviations, d1, d1)} & #{Map.get(@day_abbreviations, d2, d2)}"
  end

  defp format_days(days) when is_list(days) do
    {last, rest} = List.pop_at(days, -1)
    abbreviated = Enum.map(rest, &Map.get(@day_abbreviations, &1, &1))
    "#{Enum.join(abbreviated, ", ")} & #{Map.get(@day_abbreviations, last, last)}"
  end

  defp format_times(nil, _), do: nil
  defp format_times(_, nil), do: nil

  defp format_times(%Time{} = start_time, %Time{} = end_time) do
    # Trigger: both times in the same AM/PM period
    # Why: "4:00 - 5:30 PM" reads cleaner than "4:00 PM - 5:30 PM"
    # Outcome: omit period from start time when both share the same period
    same_period? = start_time.hour >= 12 == end_time.hour >= 12

    if same_period? do
      "#{format_time_12h(start_time, show_period: false)} - #{format_time_12h(end_time)}"
    else
      "#{format_time_12h(start_time)} - #{format_time_12h(end_time)}"
    end
  end

  defp format_time_12h(time, opts \\ [])

  defp format_time_12h(%Time{hour: hour, minute: minute}, opts) do
    {h12, period} = if hour >= 12, do: {rem(hour, 12), "PM"}, else: {hour, "AM"}
    h12 = if h12 == 0, do: 12, else: h12
    minutes_str = String.pad_leading("#{minute}", 2, "0")

    if Keyword.get(opts, :show_period, true) do
      "#{h12}:#{minutes_str} #{period}"
    else
      "#{h12}:#{minutes_str}"
    end
  end

  defp format_date_range(nil, _), do: nil
  defp format_date_range(_, nil), do: nil

  defp format_date_range(%Date{} = start_date, end_date) do
    # Trigger: end_date may be a DateTime (from :utc_datetime column) or a Date
    # Why: domain model stores end_date as DateTime; presenter needs just the date portion
    # Outcome: consistent date formatting regardless of input type
    end_date = if match?(%DateTime{}, end_date), do: DateTime.to_date(end_date), else: end_date
    "#{format_short_date(start_date)} - #{format_short_date(end_date)}, #{end_date.year}"
  end

  defp format_short_date(%Date{} = date) do
    month = Enum.at(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec), date.month - 1)
    "#{month} #{date.day}"
  end

  defp format_instructor(nil), do: nil

  defp format_instructor(instructor) do
    %{
      id: instructor.id,
      name: instructor.name,
      initials: build_initials(instructor.name),
      headshot_url: instructor.headshot_url
    }
  end

  defp build_initials(name) when is_binary(name) do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  defp build_initials(_), do: "?"

  @doc """
  Transforms a category code to a human-readable label.
  """
  @spec humanize_category(String.t() | nil) :: String.t()
  def humanize_category(nil), do: "General"
  def humanize_category("arts"), do: gettext("Arts")
  def humanize_category("education"), do: gettext("Education")
  def humanize_category("sports"), do: gettext("Sports")
  def humanize_category("music"), do: gettext("Music")
  def humanize_category(category), do: String.capitalize(category)
end

defmodule KlassHero.Enrollment.Domain.Services.EnrollmentClassifier do
  @moduledoc """
  Classifies enrollment+program pairs into active and expired groups.

  Pure domain service — receives data, returns deterministic result.
  No infrastructure dependencies.

  ## Classification Rules

  An enrollment is **expired** if either:
  - Enrollment status is `:completed` or `:cancelled`
  - Program's `end_date` is before the reference date

  Otherwise the enrollment is **active**.

  ## Sorting

  - Active: ascending by program `start_date` (nil pushed to end)
  - Expired: descending by program `end_date` (nil pushed to end)
  """

  alias KlassHero.Enrollment.Domain.Models.Enrollment
  alias KlassHero.ProgramCatalog.Domain.Models.Program

  @type enrollment_program :: {Enrollment.t(), Program.t()}

  @doc """
  Splits enrollment+program pairs into `{active, expired}` lists, both sorted.

  ## Examples

      pairs = [{enrollment, program}]
      {active, expired} = EnrollmentClassifier.classify(pairs, Date.utc_today())
  """
  @spec classify([enrollment_program()], Date.t()) ::
          {active :: [enrollment_program()], expired :: [enrollment_program()]}
  def classify(enrollment_programs, today) when is_list(enrollment_programs) do
    {active, expired} =
      Enum.split_with(enrollment_programs, fn {enrollment, program} ->
        not expired?(enrollment, program, today)
      end)

    {sort_active(active), sort_expired(expired)}
  end

  # Trigger: enrollment completed/cancelled OR program end date passed
  # Why: both conditions indicate the program is no longer active for this family
  # Outcome: returns true if the enrollment should appear in the expired section
  defp expired?(%{status: status}, _program, _today) when status in [:completed, :cancelled],
    do: true

  defp expired?(_enrollment, %{end_date: end_date}, today) when not is_nil(end_date),
    do: Date.before?(end_date, today)

  defp expired?(_enrollment, _program, _today), do: false

  # Trigger: parents want to see what's coming next first
  # Why: soonest upcoming session at top, programs without dates at bottom
  # Outcome: active list sorted ascending by start_date
  defp sort_active(pairs) do
    Enum.sort_by(pairs, fn {_e, p} -> p.start_date || ~D[9999-12-31] end, Date)
  end

  # Trigger: most recently ended programs should appear first in expired section
  # Why: recently ended programs are more relevant than old ones
  # Outcome: expired list sorted descending by end_date
  defp sort_expired(pairs) do
    Enum.sort_by(pairs, fn {_e, p} -> p.end_date || ~D[0001-01-01] end, {:desc, Date})
  end
end

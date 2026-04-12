defmodule KlassHero.Participation.Application.Commands.CorrectAttendance do
  @moduledoc """
  Use case for admin corrections to attendance records.

  Allows admins to change status and/or check-in/check-out times on a
  participation record. Requires a reason that is appended (not replaced)
  to the appropriate notes field.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @participation_reader Application.compile_env!(
                          :klass_hero,
                          [:participation, :participation_query_repository]
                        )
  @participation_repository Application.compile_env!(
                              :klass_hero,
                              [:participation, :participation_repository]
                            )

  @type params :: %{
          required(:record_id) => String.t(),
          required(:reason) => String.t(),
          optional(:status) => ParticipationRecord.status(),
          optional(:check_in_at) => DateTime.t(),
          optional(:check_out_at) => DateTime.t()
        }

  @type result :: {:ok, ParticipationRecord.t()} | {:error, atom()}

  @spec execute(params()) :: result()
  def execute(%{record_id: record_id, reason: reason} = params) do
    with :ok <- validate_reason(reason),
         correction_attrs = build_correction_attrs(params),
         {:ok, record} <- @participation_reader.get_by_id(record_id),
         {:ok, corrected} <- ParticipationRecord.admin_correct(record, correction_attrs) do
      corrected_with_notes = append_correction_reason(corrected, record, params)
      @participation_repository.update(corrected_with_notes)
    end
  end

  def execute(%{record_id: _record_id}), do: {:error, :reason_required}

  defp validate_reason(reason) when is_binary(reason) do
    if String.trim(reason) == "", do: {:error, :reason_required}, else: :ok
  end

  defp validate_reason(_), do: {:error, :reason_required}

  defp build_correction_attrs(params) do
    params
    |> Map.take([:status, :check_in_at, :check_out_at])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Trigger: check_in_at was changed
  # Why: correction reason belongs alongside the data that was corrected
  # Outcome: reason appended to check_in_notes
  defp append_correction_reason(corrected, original, %{reason: reason} = params) do
    note = "[Admin correction] #{String.trim(reason)}"

    cond do
      Map.has_key?(params, :check_in_at) and params.check_in_at != original.check_in_at ->
        append_to_field(corrected, :check_in_notes, note)

      Map.has_key?(params, :check_out_at) and params.check_out_at != original.check_out_at ->
        append_to_field(corrected, :check_out_notes, note)

      Map.has_key?(params, :status) and params.status != original.status ->
        append_to_field(corrected, :check_in_notes, note)

      true ->
        corrected
    end
  end

  defp append_to_field(record, field, note) do
    existing = Map.get(record, field)

    new_value =
      case existing do
        nil -> note
        "" -> note
        existing -> "#{existing} | #{note}"
      end

    Map.put(record, field, new_value)
  end
end

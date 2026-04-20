defmodule KlassHeroWeb.Helpers.ParticipationEditHelpers do
  @moduledoc """
  Shared helpers for the inline "edit participation record" form used by the
  provider and staff roster LiveViews.

  Translates form values (notes + optional `datetime-local` departure time)
  into a `KlassHero.Participation.correct_attendance/1` command tagged with
  the appropriate `:actor_role`.
  """

  alias KlassHero.Participation.Domain.Models.ParticipationRecord

  @type role :: :provider | :staff

  @doc """
  Pre-fill text for the edit form's notes textarea.

  Falls back to whichever notes field the edit will write to:
  `check_out_notes` once the child has departed, otherwise `check_in_notes`.
  """
  @spec default_edit_notes(ParticipationRecord.t() | map()) :: String.t()
  def default_edit_notes(%{check_out_at: %DateTime{}, check_out_notes: notes}) when is_binary(notes), do: notes

  # Departed but no check-out note yet — start the textarea empty so we don't
  # silently copy `check_in_notes` into `check_out_notes` on save.
  def default_edit_notes(%{check_out_at: %DateTime{}}), do: ""

  def default_edit_notes(%{check_in_notes: notes}) when is_binary(notes), do: notes
  def default_edit_notes(_), do: ""

  @doc """
  Build a `correct_attendance` command from raw edit-form params.

  - If a departure time is supplied AND the child has not yet departed,
    a retroactive check-out is recorded (status flip + check_out_at + notes).
  - If the child has already departed, notes go into `check_out_notes`.
  - Otherwise notes go into `check_in_notes`.
  """
  @spec build_edit_correction(ParticipationRecord.t() | map(), map(), role()) ::
          {:ok, map()} | {:error, :invalid_datetime}
  def build_edit_correction(record, params, role) when role in [:provider, :staff] do
    notes = params |> Map.get("notes", "") |> to_string()
    check_out_at_input = params |> Map.get("check_out_at", "") |> to_string() |> String.trim()
    base = %{record_id: record.id, actor_role: role}

    cond do
      check_out_at_input != "" and is_nil(record.check_out_at) ->
        with {:ok, dt} <- parse_datetime_local(check_out_at_input) do
          {:ok,
           base
           |> Map.put(:status, :checked_out)
           |> Map.put(:check_out_at, dt)
           |> Map.put(:check_out_notes, notes)}
        end

      not is_nil(record.check_out_at) ->
        {:ok, Map.put(base, :check_out_notes, notes)}

      true ->
        {:ok, Map.put(base, :check_in_notes, notes)}
    end
  end

  # datetime-local inputs submit "YYYY-MM-DDTHH:MM" (no seconds, no zone)
  @spec parse_datetime_local(String.t()) :: {:ok, DateTime.t()} | {:error, :invalid_datetime}
  defp parse_datetime_local(input) do
    normalized = if byte_size(input) == 16, do: input <> ":00", else: input

    case NaiveDateTime.from_iso8601(normalized) do
      {:ok, ndt} -> {:ok, DateTime.from_naive!(ndt, "Etc/UTC")}
      _ -> {:error, :invalid_datetime}
    end
  end
end

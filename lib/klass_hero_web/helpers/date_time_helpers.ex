defmodule KlassHeroWeb.Helpers.DateTimeHelpers do
  @moduledoc """
  Helpers for parsing form datetime input.
  """

  @doc """
  Parses a datetime string from an HTML `datetime-local` input
  (which omits seconds and timezone) into a UTC `%DateTime{}`.

  Returns `nil` for `nil`, empty string, non-binary input, or any
  unparseable value.

  ## Examples

      iex> dt = KlassHeroWeb.Helpers.DateTimeHelpers.parse_datetime_local("2026-04-22T14:30")
      iex> dt.time_zone
      "Etc/UTC"

      iex> KlassHeroWeb.Helpers.DateTimeHelpers.parse_datetime_local(nil)
      nil

      iex> KlassHeroWeb.Helpers.DateTimeHelpers.parse_datetime_local("")
      nil
  """
  @spec parse_datetime_local(any()) :: DateTime.t() | nil
  def parse_datetime_local(nil), do: nil
  def parse_datetime_local(""), do: nil

  def parse_datetime_local(value) when is_binary(value) do
    case DateTime.from_iso8601(value <> ":00Z") do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  def parse_datetime_local(_), do: nil
end

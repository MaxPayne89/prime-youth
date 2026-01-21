defmodule KlassHero.Participation.Application.UseCases.Shared do
  @moduledoc """
  Shared utilities for Participation use cases.
  """

  @doc """
  Normalizes notes by trimming whitespace and converting empty strings to nil.

  ## Examples

      iex> normalize_notes(nil)
      nil

      iex> normalize_notes("  hello  ")
      "hello"

      iex> normalize_notes("   ")
      nil
  """
  @spec normalize_notes(String.t() | nil) :: String.t() | nil
  def normalize_notes(nil), do: nil

  def normalize_notes(notes) when is_binary(notes) do
    case String.trim(notes) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end

defmodule KlassHero.Participation.Application.UseCases.Shared do
  @moduledoc """
  Shared utilities for Participation use cases.
  """

  require Logger

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

  @doc """
  Logs the result of a PubSub event publish attempt.

  Silently succeeds on `:ok`, logs a warning on error so callers
  don't need to duplicate logging logic.
  """
  @spec log_publish_result(:ok | {:error, term()}, String.t()) :: :ok
  def log_publish_result(:ok, _note_id), do: :ok

  def log_publish_result({:error, reason}, note_id) do
    Logger.warning("[Participation] PubSub publish failed",
      note_id: note_id,
      reason: inspect(reason)
    )
  end
end

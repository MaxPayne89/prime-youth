defmodule PrimeYouth.ProgramCatalog.Application.UseCases.FilterPrograms do
  @moduledoc """
  Filters a list of programs by title using word-boundary matching.

  This use case implements the real-time filtering logic for the program catalog.
  It matches programs where any word in the title starts with the search query,
  ignoring special characters and case differences.
  """

  alias PrimeYouth.ProgramCatalog.Domain.Models.Program

  @doc """
  Filters programs by search query using word-boundary matching.

  Returns all programs if query is empty or whitespace-only.
  Returns programs where any word in the title starts with the normalized query.

  ## Examples

      iex> programs = [
      ...>   %Program{id: "1", title: "After School Soccer"},
      ...>   %Program{id: "2", title: "Summer Dance Camp"}
      ...> ]
      iex> FilterPrograms.execute(programs, "soc")
      [%Program{id: "1", title: "After School Soccer"}]

      iex> FilterPrograms.execute(programs, "")
      [%Program{id: "1", title: "After School Soccer"}, %Program{id: "2", title: "Summer Dance Camp"}]
  """
  @spec execute([Program.t()], String.t()) :: [Program.t()]
  def execute(programs, query) when is_list(programs) and is_binary(query) do
    normalized_query = normalize(query)

    if String.trim(normalized_query) == "" do
      programs
    else
      Enum.filter(programs, fn program ->
        matches_word_boundary?(program.title, normalized_query)
      end)
    end
  end

  # Checks if any word in the title starts with the query.
  # Both title and query are normalized before matching.
  @spec matches_word_boundary?(String.t(), String.t()) :: boolean()
  defp matches_word_boundary?(title, query) do
    normalized_title = normalize(title)

    normalized_title
    |> String.split(~r/\s+/, trim: true)
    |> Enum.any?(&String.starts_with?(&1, query))
  end

  # Normalizes text by removing special characters and converting to lowercase.
  # Special characters removed: !, ., ,, ?, ;, :, @, #, $, %, &, *, (, ), [, ], {, }, ", ', `
  @spec normalize(String.t()) :: String.t()
  defp normalize(text) do
    text
    |> String.replace(~r/[^\w\s]/u, "")
    |> String.downcase()
  end
end

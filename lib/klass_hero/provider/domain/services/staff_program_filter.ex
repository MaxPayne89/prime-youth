defmodule KlassHero.Provider.Domain.Services.StaffProgramFilter do
  @moduledoc """
  Filters programs by staff member tag assignments.

  Pure domain service with no dependencies on ports, adapters, or other contexts.
  Tags use the same vocabulary as program categories (from `KlassHero.Shared.Categories`).

  An empty tags list means the staff member sees all programs for their provider.
  A populated tags list restricts visibility to programs whose category matches a tag.
  """

  @spec filter_by_tags([map()], [String.t()]) :: [map()]
  def filter_by_tags(programs, []), do: programs

  def filter_by_tags(programs, tags) when is_list(tags) do
    Enum.filter(programs, &(&1.category in tags))
  end
end

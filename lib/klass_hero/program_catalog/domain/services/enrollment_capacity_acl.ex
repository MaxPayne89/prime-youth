defmodule KlassHero.ProgramCatalog.Domain.Services.EnrollmentCapacityACL do
  @moduledoc """
  Anti-corruption layer for reading enrollment capacity from the Enrollment context.

  The Program Catalog context doesn't own capacity data — it queries the
  Enrollment context through this ACL to display remaining spots.
  """

  alias KlassHero.Enrollment

  @doc """
  Returns remaining capacity for a program.

  - `{:ok, non_neg_integer()}` — remaining spots
  - `{:ok, :unlimited}` — no maximum configured
  """
  @spec remaining_capacity(String.t()) :: {:ok, non_neg_integer() | :unlimited}
  def remaining_capacity(program_id) do
    Enrollment.remaining_capacity(program_id)
  end
end

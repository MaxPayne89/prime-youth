defmodule KlassHero.ProgramCatalog.Adapters.Driven.ACL.EnrollmentCapacityACL do
  @moduledoc """
  Anti-corruption layer for reading enrollment capacity from the Enrollment context.

  The Program Catalog context doesn't own capacity data — it queries the
  Enrollment context through this ACL to display remaining spots.

  Placed in the adapters layer because it calls another context's facade,
  which would violate domain purity if kept in domain/services/.
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

  @doc """
  Returns remaining capacity for multiple programs in a single batch query.
  """
  @spec remaining_capacities([String.t()]) :: %{String.t() => non_neg_integer() | :unlimited}
  def remaining_capacities(program_ids) do
    Enrollment.get_remaining_capacities(program_ids)
  end
end

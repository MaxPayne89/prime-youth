defmodule PrimeYouth.Attendance.Adapters.Driven.FamilyContext.ChildNameResolver do
  @moduledoc """
  Adapter for resolving child names from Family context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Attendance and Family
  bounded contexts. It:

  1. Queries Family context's ChildRepository (respecting bounded context isolation)
  2. Transforms Child domain model to primitive string (anti-corruption)
  3. Maps Family error semantics to Attendance error semantics

  ## Architecture

  ```
  Attendance Use Case → ForResolvingChildNames Port → [THIS ADAPTER] → Family ChildRepository
       (uses string)        (behaviour contract)      (translates)         (owns Child model)
  ```

  The Attendance context never directly depends on `Family.Domain.Models.Child`,
  maintaining proper bounded context isolation per DDD principles.

  ## Configuration

  The Family context's ChildRepository is accessed via application configuration:

      config :prime_youth, :family,
        child_repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.ChildRepository

  This allows for different implementations in different environments (e.g., in-memory for tests).

  ## Error Mapping

  Family errors are mapped to Attendance semantics:

  - `:not_found` (Family) → `:child_not_found` (Attendance)
  - Other database errors pass through unchanged

  This semantic mapping prevents Family context implementation details from
  leaking into Attendance context.
  """

  @behaviour PrimeYouth.Attendance.Domain.Ports.ForResolvingChildNames

  alias PrimeYouth.Family.Domain.Models.Child

  require Logger

  @impl true
  def resolve_child_name(child_id) when is_binary(child_id) do
    case child_repository().get_by_id(child_id) do
      {:ok, child} ->
        # Transform Child domain model to primitive string within adapter boundary
        child_name = Child.full_name(child)
        {:ok, child_name}

      {:error, :not_found} ->
        # Map Family error semantics to Attendance semantics
        {:error, :child_not_found}

      {:error, error} ->
        # Pass through database errors unchanged
        {:error, error}
    end
  end

  # Dependency injection: fetch ChildRepository from Family context configuration
  defp child_repository do
    Application.get_env(:prime_youth, :family)[:child_repository]
  end
end

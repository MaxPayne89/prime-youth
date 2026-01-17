defmodule KlassHero.Participation.Adapters.Driven.IdentityContext.ChildNameResolver do
  @moduledoc """
  Adapter for resolving child names from Identity context.

  ## Anti-Corruption Layer

  This adapter serves as an anti-corruption layer between the Participation and Identity
  bounded contexts. It:

  1. Queries Identity context's ChildRepository (respecting bounded context isolation)
  2. Transforms Child domain model to primitive string (anti-corruption)
  3. Maps Identity error semantics to Participation error semantics

  ## Architecture

  ```
  Participation Use Case → ForResolvingChildNames Port → [THIS ADAPTER] → Identity ChildRepository
       (uses string)        (behaviour contract)      (translates)         (owns Child model)
  ```

  The Participation context never directly depends on `Identity.Domain.Models.Child`,
  maintaining proper bounded context isolation per DDD principles.

  ## Configuration

  The Identity context's ChildRepository is accessed via application configuration:

      config :klass_hero, :identity,
        for_storing_children: KlassHero.Identity.Adapters.Driven.Persistence.Repositories.ChildRepository

  This allows for different implementations in different environments (e.g., in-memory for tests).

  ## Error Mapping

  Identity errors are mapped to Participation semantics:

  - `:not_found` (Identity) → `:child_not_found` (Participation)
  - Other database errors pass through unchanged

  This semantic mapping prevents Identity context implementation details from
  leaking into Participation context.
  """

  @behaviour KlassHero.Participation.Domain.Ports.ForResolvingChildNames

  alias KlassHero.Identity.Domain.Models.Child

  @impl true
  def resolve_child_name(child_id) when is_binary(child_id) do
    case child_repository().get_by_id(child_id) do
      {:ok, child} ->
        # Transform Child domain model to primitive string within adapter boundary
        child_name = Child.full_name(child)
        {:ok, child_name}

      {:error, :not_found} ->
        # Map Identity error semantics to Participation semantics
        {:error, :child_not_found}

      {:error, error} ->
        # Pass through database errors unchanged
        {:error, error}
    end
  end

  # Dependency injection: fetch ChildRepository from Identity context configuration
  defp child_repository do
    Application.get_env(:klass_hero, :identity)[:for_storing_children]
  end
end

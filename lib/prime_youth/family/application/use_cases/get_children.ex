defmodule PrimeYouth.Family.Application.UseCases.GetChildren do
  @moduledoc """
  Use case for retrieving children from the Family context.

  This use case orchestrates the retrieval of the current user's children
  from the repository. It supports both simple and extended data variants
  based on the needs of the calling context.

  ## Architecture

  This use case follows the Application Layer pattern in DDD/Ports & Adapters:
  - Coordinates domain operations (via repository port)
  - No business logic (that belongs in domain layer)
  - No logging (that belongs in adapter layer)
  - Returns domain entities (Child structs)

  ## Dependency Injection

  The repository implementation is configured via Application config:

      config :prime_youth, :family,
        repository: PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository

  ## Usage

      # Get extended child information (default)
      {:ok, children} = GetChildren.execute()
      {:ok, children} = GetChildren.execute(:extended)

      # Get simple child information
      {:ok, children} = GetChildren.execute(:simple)
  """

  alias PrimeYouth.Family.Domain.Models.Child
  alias PrimeYouth.Family.Domain.Ports.ForManagingFamily

  @doc """
  Executes the use case to retrieve children.

  Retrieves children in either simple or extended format based on the variant parameter.
  - `:simple` - Basic information only (id, name, age)
  - `:extended` - Full information including school, sessions, progress, activities

  The default variant is `:extended` for backward compatibility.

  Returns:
  - `{:ok, [Child.t()]}` - List of children (may be empty)

  ## Examples

      # Get extended information (default)
      {:ok, children} = GetChildren.execute()
      length(children) > 0  # => true

      # Get simple information
      {:ok, children} = GetChildren.execute(:simple)
      length(children) > 0  # => true

      # Empty list
      {:ok, []} = GetChildren.execute()
  """
  @spec execute(ForManagingFamily.child_variant()) :: {:ok, [Child.t()]}
  def execute(variant \\ :extended) when variant in [:simple, :extended] do
    repository_module().list_children(variant)
  end

  # Private helper to get the configured repository module
  defp repository_module do
    Application.get_env(:prime_youth, :family)[:repository]
  end
end

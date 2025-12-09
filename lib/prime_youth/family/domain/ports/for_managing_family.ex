defmodule PrimeYouth.Family.Domain.Ports.ForManagingFamily do
  @moduledoc """
  Repository port for managing family data in the Family bounded context.

  This is a behaviour (interface) that defines the contract for family data access.
  It is implemented by adapters in the infrastructure layer (e.g., in-memory repositories).

  This port follows the Ports & Adapters architecture pattern, keeping the domain
  layer independent of infrastructure concerns.

  ## Implementations

  Current implementations:
  - `PrimeYouth.Family.Adapters.Driven.Persistence.Repositories.InMemoryFamilyRepository`
    Agent-based in-memory storage for development and testing

  Future implementations could include:
  - Database-backed repository using Ecto
  - External API integration for family data
  """

  alias PrimeYouth.Family.Domain.Models.{User, Child}

  @typedoc """
  Child data variant types.

  - `:simple` - Basic information only (id, name, age)
  - `:extended` - Full information including school, sessions, progress, activities
  """
  @type child_variant :: :simple | :extended

  @doc """
  Retrieves the current user.

  Returns the logged-in user's information. In the current implementation,
  this returns a single hardcoded user for development purposes.

  Returns:
  - `{:ok, User.t()}` - User found
  - `{:error, :not_found}` - No current user available

  ## Examples

      {:ok, user} = get_current_user()
      IO.puts(user.name)

      {:error, :not_found} = get_current_user()
  """
  @callback get_current_user() :: {:ok, User.t()} | {:error, :not_found}

  @doc """
  Lists children for the current user.

  Returns children information in either simple or extended format based on
  the variant parameter. Simple format includes only basic information (id, name, age),
  while extended format includes additional details like school, sessions, progress.

  The default variant is `:extended` for backward compatibility.

  Returns:
  - `{:ok, [Child.t()]}` - List of children (may be empty)

  ## Examples

      # Get extended child information
      {:ok, children} = list_children(:extended)
      length(children) > 0  # => true

      # Get simple child information
      {:ok, children} = list_children(:simple)
      length(children) > 0  # => true

      # Default to extended
      {:ok, children} = list_children()
  """
  @callback list_children(variant :: child_variant()) :: {:ok, [Child.t()]}
end

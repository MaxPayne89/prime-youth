defmodule PrimeYouth.Family.Domain.Models.User do
  @moduledoc """
  Domain model representing a user in the Family context.

  This is a pure domain entity representing user information without
  any infrastructure concerns. The struct enforces required fields
  and provides a clean interface for the application layer.

  ## Architecture

  This follows the Domain Layer pattern in DDD/Ports & Adapters:
  - Pure Elixir struct with no dependencies on infrastructure
  - Enforces required fields through @enforce_keys
  - Represents the domain concept of a user in the family context

  ## Fields

  - `id` - Unique identifier for the user
  - `name` - User's full name
  - `email` - User's email address
  - `avatar` - Avatar identifier or URL
  - `children_summary` - Optional summary of user's children (e.g., "2 children")
  """

  @enforce_keys [:id, :name, :email, :avatar]
  defstruct [:id, :name, :email, :avatar, :children_summary]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          email: String.t(),
          avatar: String.t(),
          children_summary: String.t() | nil
        }
end

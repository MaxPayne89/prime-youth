defmodule PrimeYouth.Family.Domain.Models.Child do
  @moduledoc """
  Domain model representing a child in the Family context.

  This is a pure domain entity representing child information without
  any infrastructure concerns. The struct enforces required fields
  and provides a clean interface for the application layer.

  ## Architecture

  This follows the Domain Layer pattern in DDD/Ports & Adapters:
  - Pure Elixir struct with no dependencies on infrastructure
  - Enforces required fields through @enforce_keys
  - Represents the domain concept of a child in the family context

  ## Variants

  The repository can provide children in two variants:
  - `:simple` - Basic information only (id, name, age)
  - `:extended` - Full information including school, sessions, progress, activities

  ## Fields

  **Required (both variants):**
  - `id` - Unique identifier for the child
  - `name` - Child's name
  - `age` - Child's age

  **Optional (extended variant):**
  - `school` - Child's school name
  - `sessions` - Number of sessions attended
  - `progress` - Progress percentage or description
  - `activities` - List of activities the child is enrolled in
  """

  @enforce_keys [:id, :name, :age]
  defstruct [:id, :name, :age, :school, :sessions, :progress, :activities]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          age: integer(),
          school: String.t() | nil,
          sessions: integer() | nil,
          progress: String.t() | integer() | nil,
          activities: [String.t()] | nil
        }
end

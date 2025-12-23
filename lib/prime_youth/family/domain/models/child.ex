defmodule PrimeYouth.Family.Domain.Models.Child do
  @moduledoc """
  Child domain entity representing a child in the family management context.

  This is a pure domain model with no persistence or infrastructure concerns.
  Validation happens at the use case boundary via Ecto changesets.

  ## Fields

  - `id` - Unique identifier for the child
  - `parent_id` - Reference to the parent (correlation ID, not FK)
  - `first_name` - Child's first name
  - `last_name` - Child's last name
  - `date_of_birth` - Child's birth date
  - `notes` - Optional notes about the child
  - `inserted_at` - When the record was created
  - `updated_at` - When the record was last updated
  """

  @enforce_keys [:id, :parent_id, :first_name, :last_name, :date_of_birth]
  defstruct [
    :id,
    :parent_id,
    :first_name,
    :last_name,
    :date_of_birth,
    :notes,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Returns the full name of the child (first name + last name).

  ## Examples

      iex> child = %Child{first_name: "Alice", last_name: "Smith", ...}
      iex> Child.full_name(child)
      "Alice Smith"
  """
  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  @doc """
  Checks if the child struct has valid structural integrity.

  This performs basic structural validation only, not business rule validation.
  Business rules (e.g., name length, date in past) are enforced at the use case
  boundary via Ecto changesets.

  ## Examples

      iex> child = %Child{id: "123", parent_id: "456", first_name: "Alice", last_name: "Smith", date_of_birth: ~D[2018-01-01]}
      iex> Child.valid?(child)
      true

      iex> child = %Child{id: nil, parent_id: "456", first_name: "Alice", last_name: "Smith", date_of_birth: ~D[2018-01-01]}
      iex> Child.valid?(child)
      false
  """
  def valid?(%__MODULE__{} = child) do
    not is_nil(child.id) and
      not is_nil(child.parent_id) and
      is_binary(child.first_name) and byte_size(child.first_name) > 0 and
      is_binary(child.last_name) and byte_size(child.last_name) > 0 and
      match?(%Date{}, child.date_of_birth)
  end

  @doc """
  Constructs a new Child struct from the given attributes.

  Raises `ArgumentError` if required keys are missing.

  ## Examples

      iex> Child.new(%{id: "123", parent_id: "456", first_name: "Alice", last_name: "Smith", date_of_birth: ~D[2018-01-01]})
      %Child{id: "123", parent_id: "456", first_name: "Alice", last_name: "Smith", date_of_birth: ~D[2018-01-01]}
  """
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end

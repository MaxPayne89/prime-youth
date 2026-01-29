defmodule KlassHero.Identity.Domain.Models.Child do
  @moduledoc """
  Child domain entity representing a child in the Identity bounded context.

  This is a pure domain model with no persistence or infrastructure concerns.
  Validation happens at the use case boundary via Ecto changesets.

  ## Fields

  - `id` - Unique identifier for the child
  - `parent_id` - Reference to the parent (correlation ID, not FK)
  - `first_name` - Child's first name
  - `last_name` - Child's last name
  - `date_of_birth` - Child's birth date
  - `emergency_contact` - Optional emergency contact info
  - `support_needs` - Optional support needs or accommodations
  - `allergies` - Optional allergy information
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
    :emergency_contact,
    :support_needs,
    :allergies,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          parent_id: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          date_of_birth: Date.t(),
          emergency_contact: String.t() | nil,
          support_needs: String.t() | nil,
          allergies: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
  Creates a new Child with validation.

  Business Rules:
  - parent_id must be present and non-empty
  - first_name must be present and non-empty
  - last_name must be present and non-empty
  - date_of_birth must be present and not in the future

  Returns:
  - `{:ok, child}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors
  """
  def new(attrs) do
    child = struct!(__MODULE__, attrs)

    case validate(child) do
      [] -> {:ok, child}
      errors -> {:error, errors}
    end
  end

  @doc """
  Validates that a child struct has valid business rules.
  """
  def valid?(%__MODULE__{} = child) do
    validate(child) == []
  end

  defp validate(%__MODULE__{} = child) do
    []
    |> validate_parent_id(child.parent_id)
    |> validate_first_name(child.first_name)
    |> validate_last_name(child.last_name)
    |> validate_date_of_birth(child.date_of_birth)
  end

  defp validate_parent_id(errors, parent_id) when is_binary(parent_id) do
    trimmed = String.trim(parent_id)

    if trimmed == "" do
      ["Parent ID cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_parent_id(errors, _), do: ["Parent ID must be a string" | errors]

  defp validate_first_name(errors, first_name) when is_binary(first_name) do
    trimmed = String.trim(first_name)

    if trimmed == "" do
      ["First name cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_first_name(errors, _), do: ["First name must be a string" | errors]

  defp validate_last_name(errors, last_name) when is_binary(last_name) do
    trimmed = String.trim(last_name)

    if trimmed == "" do
      ["Last name cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_last_name(errors, _), do: ["Last name must be a string" | errors]

  defp validate_date_of_birth(errors, %Date{} = date) do
    if Date.after?(date, Date.utc_today()) do
      ["Date of birth cannot be in the future" | errors]
    else
      errors
    end
  end

  defp validate_date_of_birth(errors, _), do: ["Date of birth must be a date" | errors]
end

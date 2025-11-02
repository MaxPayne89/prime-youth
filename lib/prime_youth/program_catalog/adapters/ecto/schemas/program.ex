defmodule PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.Program do
  @moduledoc """
  Ecto schema for Program entity persistence.

  This is the infrastructure adapter that maps the Program domain entity to database tables.
  Separates persistence concerns from business logic following Ports & Adapters architecture.

  ## Associations

  - `belongs_to :provider` - Program provider (from ProgramCatalog context)
  - `has_many :schedules` - Program schedules (ProgramSchedule)
  - `has_many :locations` - Program locations (Location)

  ## Embedded Schemas

  Uses embedded schemas for value objects to maintain domain purity:
  - `age_range` - AgeRange value object
  - `pricing` - Pricing value object
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias PrimeYouth.ProgramCatalog.Adapters.Ecto.Schemas.{
    ProgramSchedule,
    Location,
    Provider
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "programs" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :secondary_categories, {:array, :string}, default: []
    field :age_min, :integer
    field :age_max, :integer
    field :capacity, :integer
    field :current_enrollment, :integer, default: 0
    field :price_amount, :decimal
    field :price_currency, :string, default: "USD"
    field :price_unit, :string
    field :has_discount, :boolean, default: false
    field :discount_amount, :decimal
    field :status, :string
    field :is_prime_youth, :boolean, default: false
    field :featured, :boolean, default: false
    field :archived_at, :utc_datetime

    belongs_to :provider, Provider
    has_many :schedules, ProgramSchedule, on_delete: :delete_all
    has_many :locations, Location, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new program.

  Validates all required fields, business rules, and associations.

  ## Required Fields

  - title, description, provider_id, category
  - age_min, age_max, capacity
  - price_amount, price_unit

  ## Optional Fields

  - secondary_categories, current_enrollment
  - has_discount, discount_amount
  - status (defaults based on is_prime_youth)
  - is_prime_youth, featured, archived_at

  ## Business Rules

  - title: 3-200 characters
  - description: 10-5000 characters
  - age_min: 0-18, must be <= age_max
  - age_max: 0-18, must be >= age_min
  - capacity: > 0
  - current_enrollment: >= 0, <= capacity
  - secondary_categories: max 3 items
  - price_amount: >= 0
  - discount_amount: < price_amount (if has_discount)
  - category: must be valid ProgramCategory
  - status: must be valid ApprovalStatus
  """
  def changeset(program, attrs) do
    program
    |> cast(attrs, [
      :title,
      :description,
      :provider_id,
      :category,
      :secondary_categories,
      :age_min,
      :age_max,
      :capacity,
      :current_enrollment,
      :price_amount,
      :price_currency,
      :price_unit,
      :has_discount,
      :discount_amount,
      :status,
      :is_prime_youth,
      :featured,
      :archived_at
    ])
    |> validate_required([
      :title,
      :description,
      :provider_id,
      :category,
      :age_min,
      :age_max,
      :capacity,
      :price_amount,
      :price_unit
    ])
    |> validate_length(:title, min: 3, max: 200)
    |> validate_length(:description, min: 10, max: 5000)
    |> validate_number(:age_min, greater_than_or_equal_to: 0, less_than_or_equal_to: 18)
    |> validate_number(:age_max, greater_than_or_equal_to: 0, less_than_or_equal_to: 18)
    |> validate_number(:capacity, greater_than: 0)
    |> validate_number(:current_enrollment, greater_than_or_equal_to: 0)
    |> validate_number(:price_amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:category, valid_categories())
    |> validate_inclusion(:status, valid_statuses())
    |> validate_inclusion(:price_unit, ["session", "week", "month", "program"])
    |> validate_age_range()
    |> validate_enrollment_capacity()
    |> validate_secondary_categories_count()
    |> validate_discount()
    |> set_default_status()
    |> foreign_key_constraint(:provider_id)
    |> cast_assoc(:schedules, required: true)
    |> cast_assoc(:locations, required: true)
  end

  # Private validation helpers

  defp validate_age_range(changeset) do
    age_min = get_field(changeset, :age_min)
    age_max = get_field(changeset, :age_max)

    if age_min && age_max && age_min > age_max do
      add_error(changeset, :age_min, "must be less than or equal to age_max")
    else
      changeset
    end
  end

  defp validate_enrollment_capacity(changeset) do
    current_enrollment = get_field(changeset, :current_enrollment, 0)
    capacity = get_field(changeset, :capacity)

    if capacity && current_enrollment > capacity do
      add_error(changeset, :current_enrollment, "cannot exceed capacity")
    else
      changeset
    end
  end

  defp validate_secondary_categories_count(changeset) do
    case get_field(changeset, :secondary_categories) do
      nil ->
        changeset

      categories when is_list(categories) ->
        if length(categories) > 3 do
          add_error(changeset, :secondary_categories, "cannot have more than 3 items")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_discount(changeset) do
    has_discount = get_field(changeset, :has_discount, false)
    discount_amount = get_field(changeset, :discount_amount)
    price_amount = get_field(changeset, :price_amount)

    cond do
      has_discount && is_nil(discount_amount) ->
        add_error(changeset, :discount_amount, "is required when has_discount is true")

      has_discount && discount_amount && price_amount && Decimal.compare(discount_amount, price_amount) != :lt ->
        add_error(changeset, :discount_amount, "must be less than price_amount")

      true ->
        changeset
    end
  end

  defp set_default_status(changeset) do
    status = get_field(changeset, :status)
    is_prime_youth = get_field(changeset, :is_prime_youth, false)

    if is_nil(status) do
      default_status = if is_prime_youth, do: "approved", else: "draft"
      put_change(changeset, :status, default_status)
    else
      changeset
    end
  end

  defp valid_categories do
    [
      "sports",
      "arts",
      "music",
      "stem",
      "language",
      "academic",
      "outdoor",
      "cultural",
      "leadership",
      "creative_writing",
      "cooking",
      "other"
    ]
  end

  defp valid_statuses do
    ["draft", "pending_approval", "approved", "rejected", "archived"]
  end
end

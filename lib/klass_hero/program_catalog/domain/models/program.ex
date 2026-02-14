defmodule KlassHero.ProgramCatalog.Domain.Models.Program do
  @moduledoc """
  Pure domain entity representing an afterschool program, camp, or class trip.

  This is the aggregate root for the Program Catalog bounded context.
  Contains only business logic and validation rules, no database dependencies.
  """

  alias KlassHero.ProgramCatalog.Domain.Models.Instructor
  alias KlassHero.ProgramCatalog.Domain.Services.ProgramCategories

  @enforce_keys [:title, :description, :category, :price]

  defstruct [
    :id,
    :provider_id,
    :title,
    :description,
    :category,
    :schedule,
    :age_range,
    :price,
    :pricing_period,
    :icon_path,
    :end_date,
    :lock_version,
    :location,
    :cover_image_url,
    :instructor,
    :inserted_at,
    :updated_at,
    spots_available: 0
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          provider_id: String.t(),
          title: String.t(),
          description: String.t(),
          category: String.t(),
          schedule: String.t() | nil,
          age_range: String.t() | nil,
          price: Decimal.t(),
          pricing_period: String.t() | nil,
          spots_available: non_neg_integer(),
          icon_path: String.t() | nil,
          end_date: DateTime.t() | nil,
          lock_version: non_neg_integer() | nil,
          location: String.t() | nil,
          cover_image_url: String.t() | nil,
          instructor: Instructor.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  # Internal: constructs from trusted persistence data (post-Ecto validation).
  # External callers must use create/1 (untrusted) or apply_changes/2 (mutation).
  @doc false
  @spec new(map()) :: {:ok, t()}
  def new(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  end

  # Internal: bang variant for mapper reconstruction from trusted data.
  @doc false
  @spec new!(map()) :: t()
  def new!(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Checks if the program struct has valid business invariants.

  Note: Full validation is performed by the Ecto schema. This function
  only checks runtime invariants that matter for business logic.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = program) do
    is_binary(program.title) and String.trim(program.title) != "" and
      is_binary(program.description) and String.trim(program.description) != "" and
      match?(%Decimal{}, program.price) and Decimal.compare(program.price, Decimal.new(0)) != :lt and
      is_integer(program.spots_available) and program.spots_available >= 0
  end

  @doc """
  Creates a new Program from untrusted input, validating business invariants.

  Unlike `new/1` (which assumes trusted data from persistence), this function
  validates all business rules before constructing the struct.

  Returns `{:ok, Program.t()}` with `id: nil` — the persistence layer assigns the ID.
  """
  @spec create(map()) :: {:ok, t()} | {:error, [String.t()]}
  def create(attrs) when is_map(attrs) do
    attrs = normalize_keys(attrs)

    with {:ok, instructor} <- build_instructor_from_attrs(attrs) do
      build_base(attrs, instructor)
    end
  end

  @doc """
  Applies changes to an existing Program, re-validating all business invariants.

  Takes the current program and a map of changes. Only keys present in the
  changes map are updated; all others are preserved.
  """
  @spec apply_changes(t(), map()) :: {:ok, t()} | {:error, [String.t()]}
  def apply_changes(%__MODULE__{} = program, changes) when is_map(changes) do
    with {:ok, instructor} <- resolve_instructor(program, changes) do
      updated = merge_fields(program, changes, instructor)
      errors = validate_mutation_invariants(updated)

      if errors == [] do
        {:ok, updated}
      else
        {:error, errors}
      end
    end
  end

  @doc """
  Checks if the program is sold out (no spots available).
  """
  @spec sold_out?(t()) :: boolean()
  def sold_out?(%__MODULE__{spots_available: spots}), do: spots == 0

  @doc """
  Checks if the program is free (price is $0).
  """
  @spec free?(t()) :: boolean()
  def free?(%__MODULE__{price: price}), do: Decimal.equal?(price, Decimal.new(0))

  # ============================================================================
  # create/1 helpers
  # ============================================================================

  # Trigger: attrs may arrive with string keys (e.g. from form params)
  # Why: domain model expects atom keys; String.to_existing_atom/1 prevents
  #      atom table exhaustion since struct fields are already defined
  # Outcome: unknown string keys raise ArgumentError (correct — unknown field)
  defp normalize_keys(%{__struct__: _} = attrs), do: Map.from_struct(attrs)

  defp normalize_keys(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  end

  defp build_instructor_from_attrs(%{instructor: instructor_attrs})
       when is_map(instructor_attrs) do
    case Instructor.new(instructor_attrs) do
      {:ok, instructor} -> {:ok, instructor}
      {:error, reasons} -> {:error, Enum.map(reasons, &"Instructor: #{&1}")}
    end
  end

  defp build_instructor_from_attrs(_), do: {:ok, nil}

  defp build_base(attrs, instructor) do
    errors = validate_creation_invariants(attrs)

    if errors == [] do
      {:ok,
       %__MODULE__{
         title: attrs[:title],
         description: attrs[:description],
         category: attrs[:category],
         price: attrs[:price],
         provider_id: attrs[:provider_id],
         schedule: attrs[:schedule],
         age_range: attrs[:age_range],
         pricing_period: attrs[:pricing_period],
         spots_available: attrs[:spots_available] || 0,
         icon_path: attrs[:icon_path],
         end_date: attrs[:end_date],
         location: attrs[:location],
         cover_image_url: attrs[:cover_image_url],
         instructor: instructor
       }}
    else
      {:error, errors}
    end
  end

  defp validate_creation_invariants(attrs) do
    []
    |> validate_required_string(attrs, :title, "title is required")
    |> validate_required_string(attrs, :description, "description is required")
    |> validate_category(attrs[:category])
    |> validate_price(attrs[:price])
    |> validate_spots(attrs[:spots_available])
    |> validate_provider_id(attrs[:provider_id])
  end

  defp validate_required_string(errors, attrs, key, message) do
    value = attrs[key]

    if is_binary(value) and String.trim(value) != "" do
      errors
    else
      [message | errors]
    end
  end

  defp validate_category(errors, category) when is_binary(category) do
    if ProgramCategories.valid_program_category?(category) do
      errors
    else
      ["category is invalid" | errors]
    end
  end

  defp validate_category(errors, _), do: ["category is required" | errors]

  defp validate_price(errors, %Decimal{} = price) do
    if Decimal.compare(price, Decimal.new(0)) == :lt do
      ["price must be greater than or equal to 0" | errors]
    else
      errors
    end
  end

  defp validate_price(errors, _), do: ["price is required" | errors]

  defp validate_spots(errors, nil), do: errors
  defp validate_spots(errors, spots) when is_integer(spots) and spots >= 0, do: errors

  defp validate_spots(errors, _),
    do: ["spots available must be greater than or equal to 0" | errors]

  defp validate_provider_id(errors, id) when is_binary(id) and byte_size(id) > 0, do: errors
  defp validate_provider_id(errors, _), do: ["provider ID is required" | errors]

  # ============================================================================
  # apply_changes/2 helpers
  # ============================================================================

  defp resolve_instructor(_program, %{instructor: nil}), do: {:ok, nil}

  defp resolve_instructor(_program, %{instructor: attrs}) when is_map(attrs) do
    case Instructor.new(attrs) do
      {:ok, instructor} -> {:ok, instructor}
      {:error, reasons} -> {:error, Enum.map(reasons, &"Instructor: #{&1}")}
    end
  end

  defp resolve_instructor(program, _changes), do: {:ok, program.instructor}

  @updatable_fields ~w(title description category price spots_available schedule
                       age_range pricing_period icon_path end_date location cover_image_url)a

  defp merge_fields(program, changes, instructor) do
    merged =
      Enum.reduce(@updatable_fields, program, fn field, acc ->
        if Map.has_key?(changes, field) do
          Map.put(acc, field, Map.get(changes, field))
        else
          acc
        end
      end)

    %{merged | instructor: instructor}
  end

  defp validate_mutation_invariants(program) do
    struct_fields = Map.from_struct(program)

    []
    |> validate_required_string(struct_fields, :title, "title is required")
    |> validate_required_string(struct_fields, :description, "description is required")
    |> validate_category(program.category)
    |> validate_price(program.price)
    |> validate_spots(program.spots_available)
  end
end

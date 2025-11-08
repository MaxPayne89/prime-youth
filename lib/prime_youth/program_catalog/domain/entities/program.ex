defmodule PrimeYouth.ProgramCatalog.Domain.Entities.Program do
  @moduledoc """
  Program domain entity representing an afterschool activity, camp, or class trip offering.

  This is a pure Elixir struct that encapsulates program business logic without
  infrastructure concerns. Follows DDD principles with strong business rules validation.

  ## Business Rules

  - `current_enrollment` must never exceed `capacity`
  - External provider programs (is_prime_youth=false) must go through approval workflow
  - Prime Youth programs (is_prime_youth=true) can be published directly
  - Archived programs cannot be edited or displayed in marketplace
  - Programs must have at least one schedule and one location

  ## State Transitions (ApprovalStatus)

  draft → pending_approval (submit)
  pending_approval → approved (admin approves)
  pending_approval → rejected (admin rejects)
  rejected → pending_approval (resubmit)
  approved → draft (edit published program)
  """

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.{
    AgeRange,
    ApprovalStatus,
    Pricing,
    ProgramCategory
  }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          title: String.t(),
          description: String.t(),
          provider_id: String.t(),
          category: ProgramCategory.t(),
          secondary_categories: [ProgramCategory.t()],
          age_range: AgeRange.t(),
          capacity: non_neg_integer(),
          current_enrollment: non_neg_integer(),
          pricing: Pricing.t(),
          status: ApprovalStatus.t(),
          is_prime_youth: boolean(),
          featured: boolean(),
          archived_at: DateTime.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @enforce_keys [:title, :description, :provider_id, :category, :age_range, :capacity, :pricing]

  defstruct [
    :id,
    :title,
    :description,
    :provider_id,
    :category,
    :age_range,
    :pricing,
    :archived_at,
    :created_at,
    :updated_at,
    secondary_categories: [],
    capacity: 0,
    current_enrollment: 0,
    status: nil,
    is_prime_youth: false,
    featured: false
  ]

  @doc """
  Creates a new Program entity with validation.

  ## Parameters

  - `attrs`: Map of program attributes

  ## Returns

  - `{:ok, %Program{}}` if valid
  - `{:error, reason}` if validation fails

  ## Examples

      iex> PrimeYouth.ProgramCatalog.Domain.Entities.Program.new(%{
      ...>   title: "Summer Soccer Camp",
      ...>   description: "Fun soccer camp for kids",
      ...>   provider_id: "provider-uuid",
      ...>   category: %ProgramCategory{value: :sports},
      ...>   age_range: %AgeRange{min_age: 5, max_age: 10},
      ...>   capacity: 20,
      ...>   pricing: %Pricing{amount: 200, currency: "USD", unit: "program"}
      ...> })
      {:ok, %Program{}}

  """
  def new(attrs) when is_map(attrs) do
    with {:ok, attrs} <- validate_required_fields(attrs),
         {:ok, attrs} <- validate_title(attrs),
         {:ok, attrs} <- validate_description(attrs),
         {:ok, attrs} <- validate_capacity(attrs),
         {:ok, attrs} <- validate_enrollment(attrs),
         {:ok, attrs} <- validate_secondary_categories(attrs),
         {:ok, attrs} <- set_default_status(attrs) do
      program = struct(__MODULE__, attrs)
      {:ok, program}
    end
  end

  @doc """
  Validates that current enrollment does not exceed capacity.
  """
  def validate_enrollment_capacity(%__MODULE__{} = program) do
    if program.current_enrollment <= program.capacity do
      {:ok, program}
    else
      {:error, :enrollment_exceeds_capacity}
    end
  end

  @doc """
  Checks if the program is archived.
  """
  def archived?(%__MODULE__{archived_at: nil}), do: false
  def archived?(%__MODULE__{archived_at: %DateTime{}}), do: true

  @doc """
  Checks if the program is visible in marketplace.

  Programs are visible if:
  - Not archived
  - Status is :approved
  """
  def visible_in_marketplace?(%__MODULE__{} = program) do
    not archived?(program) and
      ApprovalStatus.approved?(program.status)
  end

  @doc """
  Checks if the program can be edited.

  Archived programs cannot be edited.
  """
  def editable?(%__MODULE__{} = program) do
    not archived?(program)
  end

  @doc """
  Submits program for approval (draft → pending_approval).
  """
  def submit_for_approval(%__MODULE__{status: %ApprovalStatus{value: "draft"}} = program) do
    case ApprovalStatus.new("pending_approval") do
      {:ok, new_status} -> {:ok, %{program | status: new_status}}
      error -> error
    end
  end

  def submit_for_approval(%__MODULE__{}) do
    {:error, :invalid_state_transition}
  end

  # Private validation functions

  defp validate_required_fields(attrs) do
    required = [:title, :description, :provider_id, :category, :age_range, :capacity, :pricing]

    missing =
      Enum.filter(required, fn field ->
        not Map.has_key?(attrs, field) or is_nil(Map.get(attrs, field))
      end)

    if Enum.empty?(missing) do
      {:ok, attrs}
    else
      {:error, {:missing_required_fields, missing}}
    end
  end

  defp validate_title(%{title: title} = attrs) do
    title_length = String.length(title)

    cond do
      title_length < 3 -> {:error, :title_too_short}
      title_length > 200 -> {:error, :title_too_long}
      true -> {:ok, attrs}
    end
  end

  defp validate_description(%{description: description} = attrs) do
    desc_length = String.length(description)

    cond do
      desc_length < 10 -> {:error, :description_too_short}
      desc_length > 5000 -> {:error, :description_too_long}
      true -> {:ok, attrs}
    end
  end

  defp validate_capacity(%{capacity: capacity} = attrs) when is_integer(capacity) do
    if capacity > 0 do
      {:ok, attrs}
    else
      {:error, :invalid_capacity}
    end
  end

  defp validate_capacity(_), do: {:error, :invalid_capacity}

  defp validate_enrollment(attrs) do
    current_enrollment = Map.get(attrs, :current_enrollment, 0)
    capacity = Map.get(attrs, :capacity, 0)

    cond do
      not is_integer(current_enrollment) ->
        {:error, :invalid_enrollment}

      current_enrollment < 0 ->
        {:error, :negative_enrollment}

      current_enrollment > capacity ->
        {:error, :enrollment_exceeds_capacity}

      true ->
        {:ok, Map.put(attrs, :current_enrollment, current_enrollment)}
    end
  end

  defp validate_secondary_categories(attrs) do
    secondary = Map.get(attrs, :secondary_categories, [])

    cond do
      not is_list(secondary) ->
        {:error, :invalid_secondary_categories}

      length(secondary) > 3 ->
        {:error, :too_many_secondary_categories}

      true ->
        {:ok, attrs}
    end
  end

  defp set_default_status(attrs) do
    case Map.get(attrs, :status) do
      nil ->
        status_string =
          if Map.get(attrs, :is_prime_youth, false) do
            "approved"
          else
            "draft"
          end

        case ApprovalStatus.new(status_string) do
          {:ok, status} -> {:ok, Map.put(attrs, :status, status)}
          error -> error
        end

      existing_status ->
        {:ok, Map.put(attrs, :status, existing_status)}
    end
  end
end

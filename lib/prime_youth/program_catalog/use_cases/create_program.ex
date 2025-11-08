defmodule PrimeYouth.ProgramCatalog.UseCases.CreateProgram do
  @moduledoc """
  Use case for creating a new program in the catalog.

  This use case orchestrates program creation with approval workflow logic.
  Pure business logic - NO logging, NO tracing, NO infrastructure concerns.

  ## Responsibilities

  - Validate program attributes
  - Verify provider permissions and verification status
  - Apply approval workflow rules based on provider type
  - Initialize program with correct status

  ## Business Rules

  - External provider programs start as :draft or :pending_approval
  - Prime Youth programs are :approved immediately (bypass workflow)
  - Providers must be verified to create programs
  - Provider ID in attributes must match the provider parameter

  ## Usage

      # External provider creates draft program
      CreateProgram.execute(attrs, provider)

      # External provider submits for approval
      CreateProgram.execute(Map.put(attrs, :submit_for_approval, true), provider)

      # Prime Youth creates approved program
      CreateProgram.execute(attrs, prime_youth_provider)
  """

  alias PrimeYouth.ProgramCatalog.Domain.Entities.{Program, Provider}

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.{
    AgeRange,
    ApprovalStatus,
    Pricing,
    ProgramCategory
  }

  @doc """
  Execute the create program use case.

  Creates a new program with validation and approval workflow logic.

  ## Parameters

  - `attrs` - Map of program attributes
  - `provider` - Provider entity creating the program

  ## Returns

  - `{:ok, %Program{}}` on success
  - `{:error, reason}` on validation failure

  ## Examples

      iex> CreateProgram.execute(%{
      ...>   title: "Soccer Camp",
      ...>   description: "Fun soccer activities",
      ...>   provider_id: provider.id,
      ...>   category: :sports,
      ...>   age_range: %{min_age: 6, max_age: 12},
      ...>   capacity: 20,
      ...>   pricing: %{amount: 299.99, currency: "USD", payment_type: :per_session}
      ...> }, provider)
      {:ok, %Program{}}
  """
  def execute(attrs, %Provider{} = provider) when is_map(attrs) do
    with :ok <- validate_provider(provider),
         :ok <- validate_provider_match(attrs[:provider_id], provider.id),
         {:ok, category} <- build_category(attrs[:category]),
         {:ok, age_range} <- build_age_range(attrs[:age_range]),
         {:ok, pricing} <- build_pricing(attrs[:pricing]),
         {:ok, status} <- determine_initial_status(provider, attrs[:submit_for_approval]),
         :ok <- validate_title(attrs[:title]),
         :ok <- validate_description(attrs[:description]),
         :ok <- validate_capacity(attrs[:capacity]) do
      program_attrs = %{
        title: attrs[:title],
        description: attrs[:description],
        provider_id: provider.id,
        category: category,
        secondary_categories: attrs[:secondary_categories] || [],
        age_range: age_range,
        capacity: attrs[:capacity],
        current_enrollment: 0,
        pricing: pricing,
        status: status,
        is_prime_youth: provider.is_prime_youth,
        featured: attrs[:featured] || false
      }

      case Program.new(program_attrs) do
        {:ok, program} -> {:ok, program}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private validation and business logic functions

  defp validate_provider(%Provider{is_verified: false}) do
    {:error, :provider_not_verified}
  end

  defp validate_provider(%Provider{is_verified: true}), do: :ok

  defp validate_provider_match(attr_provider_id, provider_id)
       when attr_provider_id != provider_id do
    {:error, :provider_mismatch}
  end

  defp validate_provider_match(_, _), do: :ok

  defp build_category(nil), do: {:error, :category_required}

  defp build_category(category) when is_atom(category) do
    ProgramCategory.new(Atom.to_string(category))
  end

  defp build_category(category) when is_binary(category) do
    ProgramCategory.new(category)
  end

  defp build_category(_), do: {:error, :invalid_category}

  defp build_age_range(nil), do: {:error, :age_range_required}

  defp build_age_range(%{min_age: min_age, max_age: max_age}) do
    AgeRange.new(min_age, max_age)
  end

  defp build_age_range(_), do: {:error, :invalid_age_range}

  defp build_pricing(nil), do: {:error, :pricing_required}

  defp build_pricing(%{amount: amount, currency: currency, payment_type: payment_type}) do
    # Convert payment_type atom to unit string if needed
    unit = if is_atom(payment_type), do: Atom.to_string(payment_type), else: payment_type
    Pricing.new(amount, currency, unit, nil)
  end

  defp build_pricing(_), do: {:error, :invalid_pricing}

  defp determine_initial_status(%Provider{is_prime_youth: true}, _submit_for_approval) do
    # Prime Youth programs bypass approval workflow
    ApprovalStatus.new("approved")
  end

  defp determine_initial_status(%Provider{is_prime_youth: false}, true) do
    # External provider explicitly submitting for approval
    ApprovalStatus.new("pending_approval")
  end

  defp determine_initial_status(%Provider{is_prime_youth: false}, _) do
    # External provider creating draft
    ApprovalStatus.new("draft")
  end

  defp validate_title(nil), do: {:error, :title_required}

  defp validate_title(title) when is_binary(title) do
    length = String.length(title)

    cond do
      length < 3 -> {:error, :invalid_title}
      length > 200 -> {:error, :invalid_title}
      true -> :ok
    end
  end

  defp validate_title(_), do: {:error, :invalid_title}

  defp validate_description(nil), do: {:error, :description_required}

  defp validate_description(description) when is_binary(description) do
    length = String.length(description)

    cond do
      length < 10 -> {:error, :invalid_description}
      length > 5000 -> {:error, :invalid_description}
      true -> :ok
    end
  end

  defp validate_description(_), do: {:error, :invalid_description}

  defp validate_capacity(nil), do: {:error, :capacity_required}

  defp validate_capacity(capacity) when is_integer(capacity) and capacity > 0 do
    :ok
  end

  defp validate_capacity(_), do: {:error, :invalid_capacity}
end

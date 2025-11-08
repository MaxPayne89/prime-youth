defmodule PrimeYouth.ProgramCatalog.UseCases.UpdateProgram do
  @moduledoc """
  Use case for updating an existing program in the catalog.

  This use case orchestrates program updates with validation and state management.
  Pure business logic - NO logging, NO tracing, NO infrastructure concerns.

  ## Responsibilities

  - Validate update permissions (provider ownership, program status)
  - Validate updated attributes
  - Apply business rules for status transitions
  - Handle submission for approval workflow

  ## Business Rules

  - Only draft or rejected programs can be updated
  - Updating a rejected program resets it to draft status
  - Programs can be submitted for approval via update
  - Capacity cannot be reduced below current enrollment
  - Pending and approved programs cannot be edited (must withdraw first)
  - Providers can only update their own programs
  - Provider must be verified to update programs

  ## Usage

      # Update draft program fields
      UpdateProgram.execute(program, %{title: "New Title"}, provider)

      # Submit draft program for approval
      UpdateProgram.execute(program, %{submit_for_approval: true}, provider)

      # Update rejected program (resets to draft)
      UpdateProgram.execute(rejected_program, %{title: "Fixed Title"}, provider)
  """

  alias PrimeYouth.ProgramCatalog.Domain.Entities.{Program, Provider}

  alias PrimeYouth.ProgramCatalog.Domain.ValueObjects.{
    AgeRange,
    ApprovalStatus,
    Pricing,
    ProgramCategory
  }

  @doc """
  Execute the update program use case.

  Updates an existing program with validation and state management.

  ## Parameters

  - `program` - Existing Program entity to update
  - `attrs` - Map of attributes to update (partial updates supported)
  - `provider` - Provider entity performing the update

  ## Returns

  - `{:ok, %Program{}}` on success
  - `{:error, reason}` on validation failure

  ## Examples

      iex> UpdateProgram.execute(program, %{
      ...>   title: "Updated Soccer Camp",
      ...>   capacity: 25
      ...> }, provider)
      {:ok, %Program{}}

      iex> UpdateProgram.execute(program, %{
      ...>   submit_for_approval: true
      ...> }, provider)
      {:ok, %Program{status: %ApprovalStatus{value: "pending_approval"}}}
  """
  def execute(%Program{} = program, attrs, %Provider{} = provider) when is_map(attrs) do
    with :ok <- validate_provider(provider),
         :ok <- validate_provider_ownership(program, provider),
         :ok <- validate_program_status(program),
         {:ok, validated_attrs} <- validate_and_build_attrs(attrs, program),
         {:ok, new_status} <- determine_new_status(program, attrs),
         :ok <- validate_capacity_change(program, validated_attrs[:capacity]) do
      # Merge updated attributes with existing program
      updated_attrs =
        program
        |> Map.from_struct()
        |> Map.merge(validated_attrs)
        |> Map.put(:status, new_status)

      Program.new(updated_attrs)
    end
  end

  # Private validation and business logic functions

  defp validate_provider(%Provider{is_verified: false}) do
    {:error, :provider_not_verified}
  end

  defp validate_provider(%Provider{is_verified: true}), do: :ok

  defp validate_provider_ownership(%Program{provider_id: program_provider_id}, %Provider{
         id: provider_id
       })
       when program_provider_id != provider_id do
    {:error, :provider_mismatch}
  end

  defp validate_provider_ownership(_, _), do: :ok

  defp validate_program_status(%Program{status: %ApprovalStatus{value: "pending_approval"}}) do
    {:error, :cannot_update_pending}
  end

  defp validate_program_status(%Program{status: %ApprovalStatus{value: "approved"}}) do
    {:error, :cannot_update_approved}
  end

  defp validate_program_status(%Program{status: %ApprovalStatus{value: status}})
       when status in ["draft", "rejected"] do
    :ok
  end

  defp validate_capacity_change(_program, nil), do: :ok

  defp validate_capacity_change(%Program{current_enrollment: enrollment}, new_capacity)
       when new_capacity < enrollment do
    {:error, :capacity_below_enrollment}
  end

  defp validate_capacity_change(_, _), do: :ok

  defp validate_and_build_attrs(attrs, program) do
    validated_attrs = %{}

    with {:ok, validated_attrs} <- maybe_update_title(attrs, validated_attrs),
         {:ok, validated_attrs} <- maybe_update_description(attrs, validated_attrs),
         {:ok, validated_attrs} <- maybe_update_category(attrs, validated_attrs),
         {:ok, validated_attrs} <- maybe_update_age_range(attrs, validated_attrs),
         {:ok, validated_attrs} <- maybe_update_pricing(attrs, validated_attrs) do
      maybe_update_capacity(attrs, validated_attrs, program)
    end
  end

  defp maybe_update_title(%{title: title}, acc) when is_binary(title) do
    case validate_title(title) do
      :ok -> {:ok, Map.put(acc, :title, title)}
      error -> error
    end
  end

  defp maybe_update_title(_, acc), do: {:ok, acc}

  defp maybe_update_description(%{description: description}, acc) when is_binary(description) do
    case validate_description(description) do
      :ok -> {:ok, Map.put(acc, :description, description)}
      error -> error
    end
  end

  defp maybe_update_description(_, acc), do: {:ok, acc}

  defp maybe_update_category(%{category: category}, acc) do
    case build_category(category) do
      {:ok, category_vo} -> {:ok, Map.put(acc, :category, category_vo)}
      error -> error
    end
  end

  defp maybe_update_category(_, acc), do: {:ok, acc}

  defp maybe_update_age_range(%{age_range: age_range}, acc) do
    case build_age_range(age_range) do
      {:ok, age_range_vo} -> {:ok, Map.put(acc, :age_range, age_range_vo)}
      error -> error
    end
  end

  defp maybe_update_age_range(_, acc), do: {:ok, acc}

  defp maybe_update_pricing(%{pricing: pricing}, acc) do
    case build_pricing(pricing) do
      {:ok, pricing_vo} -> {:ok, Map.put(acc, :pricing, pricing_vo)}
      error -> error
    end
  end

  defp maybe_update_pricing(_, acc), do: {:ok, acc}

  defp maybe_update_capacity(%{capacity: capacity}, acc, _program) when is_integer(capacity) do
    case validate_capacity(capacity) do
      :ok -> {:ok, Map.put(acc, :capacity, capacity)}
      error -> error
    end
  end

  defp maybe_update_capacity(_, acc, _program), do: {:ok, acc}

  defp determine_new_status(%Program{status: %ApprovalStatus{value: "rejected"}}, attrs) do
    # Updating a rejected program resets it to draft (unless submitting for approval)
    if attrs[:submit_for_approval] do
      ApprovalStatus.new("pending_approval")
    else
      ApprovalStatus.new("draft")
    end
  end

  defp determine_new_status(%Program{status: %ApprovalStatus{value: "draft"}}, attrs) do
    # Draft program can be submitted for approval
    if attrs[:submit_for_approval] do
      ApprovalStatus.new("pending_approval")
    else
      ApprovalStatus.new("draft")
    end
  end

  defp determine_new_status(%Program{status: status}, _attrs) do
    # Keep existing status for other cases
    {:ok, status}
  end

  # Validation helper functions (similar to CreateProgram)

  defp validate_title(title) when is_binary(title) do
    length = String.length(title)

    cond do
      length < 3 -> {:error, :invalid_title}
      length > 200 -> {:error, :invalid_title}
      true -> :ok
    end
  end

  defp validate_title(_), do: {:error, :invalid_title}

  defp validate_description(description) when is_binary(description) do
    length = String.length(description)

    cond do
      length < 10 -> {:error, :invalid_description}
      length > 5000 -> {:error, :invalid_description}
      true -> :ok
    end
  end

  defp validate_description(_), do: {:error, :invalid_description}

  defp validate_capacity(capacity) when is_integer(capacity) and capacity > 0 do
    :ok
  end

  defp validate_capacity(_), do: {:error, :invalid_capacity}

  defp build_category(category) when is_atom(category) do
    ProgramCategory.new(Atom.to_string(category))
  end

  defp build_category(category) when is_binary(category) do
    ProgramCategory.new(category)
  end

  defp build_category(_), do: {:error, :invalid_category}

  defp build_age_range(%{min_age: min_age, max_age: max_age}) do
    AgeRange.new(min_age, max_age)
  end

  defp build_age_range(_), do: {:error, :invalid_age_range}

  defp build_pricing(%{amount: amount, currency: currency, payment_type: payment_type}) do
    # Convert payment_type atom to unit string if needed
    unit = if is_atom(payment_type), do: Atom.to_string(payment_type), else: payment_type
    Pricing.new(amount, currency, unit, nil)
  end

  defp build_pricing(_), do: {:error, :invalid_pricing}
end

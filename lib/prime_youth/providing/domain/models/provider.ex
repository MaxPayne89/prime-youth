defmodule PrimeYouth.Providing.Domain.Models.Provider do
  @moduledoc """
  Pure domain entity representing a provider profile in the Providing bounded context.

  This is the aggregate root for the Providing context.
  Contains only business logic and validation rules, no database dependencies.

  Providers are linked to the Identity (Accounts) context via correlation ID (identity_id),
  not foreign key, maintaining bounded context independence.
  """

  @enforce_keys [:id, :identity_id, :business_name]

  defstruct [
    :id,
    :identity_id,
    :business_name,
    :description,
    :phone,
    :website,
    :address,
    :logo_url,
    :verified,
    :verified_at,
    :categories,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          identity_id: String.t(),
          business_name: String.t(),
          description: String.t() | nil,
          phone: String.t() | nil,
          website: String.t() | nil,
          address: String.t() | nil,
          logo_url: String.t() | nil,
          verified: boolean() | nil,
          verified_at: DateTime.t() | nil,
          categories: [String.t()] | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new Provider with validation.

  Business Rules:
  - identity_id must be present and non-empty (UUID string)
  - business_name must be present, non-empty, and <= 200 characters
  - description if present, must be non-empty and <= 1000 characters
  - phone if present, must be non-empty and <= 20 characters
  - website if present, must start with https:// and <= 500 characters
  - address if present, must be non-empty and <= 500 characters
  - logo_url if present, must be non-empty and <= 500 characters
  - verified if present, must be a boolean (defaults to false)
  - verified_at if present, must be a DateTime (independent of verified)
  - categories if present, must be a list of strings (defaults to [])

  Returns:
  - `{:ok, provider}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors

  ## Examples

      iex> Provider.new(%{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   business_name: "Kids Sports Academy"
      ...> })
      {:ok, %Provider{...}}

      iex> Provider.new(%{id: "1", identity_id: "", business_name: "Test"})
      {:error, ["Identity ID cannot be empty"]}
  """
  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) do
    attrs_with_defaults = apply_defaults(attrs)
    provider = struct!(__MODULE__, attrs_with_defaults)

    case validate(provider) do
      [] -> {:ok, provider}
      errors -> {:error, errors}
    end
  end

  defp apply_defaults(attrs) do
    attrs
    |> Map.put_new(:verified, false)
    |> Map.put_new(:categories, [])
  end

  @doc """
  Validates that a provider struct has valid business rules.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = provider) do
    validate(provider) == []
  end

  @doc """
  Checks if the provider has been verified.
  """
  @spec verified?(t()) :: boolean()
  def verified?(%__MODULE__{verified: true}), do: true
  def verified?(_), do: false

  defp validate(%__MODULE__{} = provider) do
    []
    |> validate_identity_id(provider.identity_id)
    |> validate_business_name(provider.business_name)
    |> validate_description(provider.description)
    |> validate_phone(provider.phone)
    |> validate_website(provider.website)
    |> validate_address(provider.address)
    |> validate_logo_url(provider.logo_url)
    |> validate_verified(provider.verified)
    |> validate_verified_at(provider.verified_at)
    |> validate_categories(provider.categories)
  end

  defp validate_identity_id(errors, identity_id) when is_binary(identity_id) do
    trimmed = String.trim(identity_id)

    if trimmed == "" do
      ["Identity ID cannot be empty" | errors]
    else
      errors
    end
  end

  defp validate_identity_id(errors, _), do: ["Identity ID must be a string" | errors]

  defp validate_business_name(errors, business_name) when is_binary(business_name) do
    trimmed = String.trim(business_name)

    cond do
      trimmed == "" -> ["Business name cannot be empty" | errors]
      String.length(trimmed) > 200 -> ["Business name must be 200 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_business_name(errors, _), do: ["Business name must be a string" | errors]

  defp validate_description(errors, nil), do: errors

  defp validate_description(errors, description) when is_binary(description) do
    trimmed = String.trim(description)

    cond do
      trimmed == "" -> ["Description cannot be empty if provided" | errors]
      String.length(trimmed) > 1000 -> ["Description must be 1000 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_description(errors, _), do: ["Description must be a string" | errors]

  defp validate_phone(errors, nil), do: errors

  defp validate_phone(errors, phone) when is_binary(phone) do
    trimmed = String.trim(phone)

    cond do
      trimmed == "" -> ["Phone cannot be empty if provided" | errors]
      String.length(trimmed) > 20 -> ["Phone must be 20 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_phone(errors, _), do: ["Phone must be a string" | errors]

  defp validate_website(errors, nil), do: errors

  defp validate_website(errors, website) when is_binary(website) do
    trimmed = String.trim(website)

    cond do
      trimmed == "" ->
        ["Website cannot be empty if provided" | errors]

      not String.starts_with?(trimmed, "https://") ->
        ["Website must start with https://" | errors]

      String.length(trimmed) > 500 ->
        ["Website must be 500 characters or less" | errors]

      true ->
        errors
    end
  end

  defp validate_website(errors, _), do: ["Website must be a string" | errors]

  defp validate_address(errors, nil), do: errors

  defp validate_address(errors, address) when is_binary(address) do
    trimmed = String.trim(address)

    cond do
      trimmed == "" -> ["Address cannot be empty if provided" | errors]
      String.length(trimmed) > 500 -> ["Address must be 500 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_address(errors, _), do: ["Address must be a string" | errors]

  defp validate_logo_url(errors, nil), do: errors

  defp validate_logo_url(errors, logo_url) when is_binary(logo_url) do
    trimmed = String.trim(logo_url)

    cond do
      trimmed == "" -> ["Logo URL cannot be empty if provided" | errors]
      String.length(trimmed) > 500 -> ["Logo URL must be 500 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_logo_url(errors, _), do: ["Logo URL must be a string" | errors]

  defp validate_verified(errors, nil), do: errors
  defp validate_verified(errors, verified) when is_boolean(verified), do: errors
  defp validate_verified(errors, _), do: ["Verified must be a boolean" | errors]

  defp validate_verified_at(errors, nil), do: errors
  defp validate_verified_at(errors, %DateTime{}), do: errors
  defp validate_verified_at(errors, _), do: ["Verified at must be a DateTime" | errors]

  defp validate_categories(errors, nil), do: errors

  defp validate_categories(errors, categories) when is_list(categories) do
    if Enum.all?(categories, &is_binary/1) do
      errors
    else
      ["Categories must be a list of strings" | errors]
    end
  end

  defp validate_categories(errors, _), do: ["Categories must be a list" | errors]
end

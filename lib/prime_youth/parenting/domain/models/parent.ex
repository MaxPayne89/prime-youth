defmodule PrimeYouth.Parenting.Domain.Models.Parent do
  @moduledoc """
  Pure domain entity representing a parent profile in the Parenting bounded context.

  This is the aggregate root for the Parenting context.
  Contains only business logic and validation rules, no database dependencies.

  Parents are linked to the Identity (Accounts) context via correlation ID (identity_id),
  not foreign key, maintaining bounded context independence.
  """

  @enforce_keys [:id, :identity_id]

  defstruct [
    :id,
    :identity_id,
    :display_name,
    :phone,
    :location,
    :notification_preferences,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          identity_id: String.t(),
          display_name: String.t() | nil,
          phone: String.t() | nil,
          location: String.t() | nil,
          notification_preferences: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new Parent with validation.

  Business Rules:
  - identity_id must be present and non-empty (UUID string)
  - display_name if present, must be non-empty and <= 100 characters
  - phone if present, must be non-empty and <= 20 characters
  - location if present, must be non-empty and <= 200 characters
  - notification_preferences if present, must be a map

  Returns:
  - `{:ok, parent}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors

  ## Examples

      iex> Parent.new(%{
      ...>   id: "550e8400-e29b-41d4-a716-446655440000",
      ...>   identity_id: "550e8400-e29b-41d4-a716-446655440001",
      ...>   display_name: "John Doe",
      ...>   phone: "+1234567890",
      ...>   location: "New York, NY"
      ...> })
      {:ok, %Parent{...}}

      iex> Parent.new(%{id: "1", identity_id: ""})
      {:error, ["Identity ID cannot be empty"]}
  """
  @spec new(map()) :: {:ok, t()} | {:error, [String.t()]}
  def new(attrs) do
    parent = struct!(__MODULE__, attrs)

    case validate(parent) do
      [] -> {:ok, parent}
      errors -> {:error, errors}
    end
  end

  @doc """
  Validates that a parent struct has valid business rules.

  Business Rules:
  - identity_id must be present and non-empty
  - display_name if present, must be non-empty and within length limits
  - phone if present, must be non-empty and within length limits
  - location if present, must be non-empty and within length limits
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = parent) do
    validate(parent) == []
  end

  defp validate(%__MODULE__{} = parent) do
    []
    |> validate_identity_id(parent.identity_id)
    |> validate_display_name(parent.display_name)
    |> validate_phone(parent.phone)
    |> validate_location(parent.location)
    |> validate_notification_preferences(parent.notification_preferences)
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

  defp validate_display_name(errors, nil), do: errors

  defp validate_display_name(errors, display_name) when is_binary(display_name) do
    trimmed = String.trim(display_name)

    cond do
      trimmed == "" -> ["Display name cannot be empty if provided" | errors]
      String.length(trimmed) > 100 -> ["Display name must be 100 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_display_name(errors, _), do: ["Display name must be a string" | errors]

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

  defp validate_location(errors, nil), do: errors

  defp validate_location(errors, location) when is_binary(location) do
    trimmed = String.trim(location)

    cond do
      trimmed == "" -> ["Location cannot be empty if provided" | errors]
      String.length(trimmed) > 200 -> ["Location must be 200 characters or less" | errors]
      true -> errors
    end
  end

  defp validate_location(errors, _), do: ["Location must be a string" | errors]

  defp validate_notification_preferences(errors, nil), do: errors
  defp validate_notification_preferences(errors, prefs) when is_map(prefs), do: errors

  defp validate_notification_preferences(errors, _),
    do: ["Notification preferences must be a map" | errors]

  @doc """
  Checks if the parent has notification preferences configured.
  """
  @spec has_notification_preferences?(t()) :: boolean()
  def has_notification_preferences?(%__MODULE__{notification_preferences: nil}), do: false

  def has_notification_preferences?(%__MODULE__{notification_preferences: prefs})
      when is_map(prefs) and map_size(prefs) > 0, do: true

  def has_notification_preferences?(_), do: false
end

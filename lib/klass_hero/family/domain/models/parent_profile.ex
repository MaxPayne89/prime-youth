defmodule KlassHero.Family.Domain.Models.ParentProfile do
  @moduledoc """
  Pure domain entity representing a parent profile in the Family bounded context.

  This is the aggregate root for parent-related operations in the Family context.
  Contains only business logic and validation rules, no database dependencies.

  Parents are linked to the Accounts context via correlation ID (identity_id),
  not foreign key, maintaining bounded context independence.
  """

  alias KlassHero.Shared.SubscriptionTiers

  @enforce_keys [:id, :identity_id]

  defstruct [
    :id,
    :identity_id,
    :display_name,
    :phone,
    :location,
    :notification_preferences,
    :subscription_tier,
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
          subscription_tier: :explorer | :active | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new ParentProfile with validation.

  Business Rules:
  - identity_id must be present and non-empty (UUID string)
  - display_name if present, must be non-empty and <= 100 characters
  - phone if present, must be non-empty and <= 20 characters
  - location if present, must be non-empty and <= 200 characters
  - notification_preferences if present, must be a map

  Returns:
  - `{:ok, parent_profile}` if all validations pass
  - `{:error, [reasons]}` with list of validation errors
  """
  def new(attrs) do
    parent_profile = struct!(__MODULE__, attrs)

    case validate(parent_profile) do
      [] -> {:ok, parent_profile}
      errors -> {:error, errors}
    end
  end

  @doc """
  Validates that a parent profile struct has valid business rules.
  """
  def valid?(%__MODULE__{} = parent_profile) do
    validate(parent_profile) == []
  end

  defp validate(%__MODULE__{} = parent_profile) do
    []
    |> validate_identity_id(parent_profile.identity_id)
    |> validate_display_name(parent_profile.display_name)
    |> validate_phone(parent_profile.phone)
    |> validate_location(parent_profile.location)
    |> validate_notification_preferences(parent_profile.notification_preferences)
    |> validate_subscription_tier(parent_profile.subscription_tier)
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

  defp validate_subscription_tier(errors, nil), do: errors

  defp validate_subscription_tier(errors, tier) do
    if SubscriptionTiers.valid_parent_tier?(tier) do
      errors
    else
      valid = SubscriptionTiers.parent_tiers() |> Enum.join(", ")
      ["Subscription tier must be one of: #{valid}" | errors]
    end
  end

  @doc """
  Checks if the parent profile has notification preferences configured.
  """
  def has_notification_preferences?(%__MODULE__{notification_preferences: nil}), do: false

  def has_notification_preferences?(%__MODULE__{notification_preferences: prefs})
      when is_map(prefs) and map_size(prefs) > 0, do: true

  def has_notification_preferences?(_), do: false
end

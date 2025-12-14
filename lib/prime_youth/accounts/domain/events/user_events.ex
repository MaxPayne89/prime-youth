defmodule PrimeYouth.Accounts.Domain.Events.UserEvents do
  @moduledoc """
  Factory module for creating User domain events.

  Provides convenience functions to create standardized DomainEvent structs
  for user-related events in the Accounts context.

  ## Events

  - `:user_registered` - Emitted when a new user completes registration (critical)
  - `:user_confirmed` - Emitted when a user confirms their email
  - `:user_email_changed` - Emitted when a user changes their email address
  - `:user_anonymized` - Emitted when a user's account is anonymized for GDPR deletion (critical)

  ## Validation

  Event factories perform fail-fast validation on all inputs:

  - **Aggregate validation**: Required fields must be present and non-empty
  - **Parameter validation**: String parameters must be non-empty
  - **Payload validation**: Required payload fields must be present
  - **Type validation**: All inputs must match expected types

  Validation failures raise `ArgumentError` with descriptive messages.

  ## Usage

      alias PrimeYouth.Accounts.Domain.Events.UserEvents

      # Create a user_registered event (critical by default)
      event = UserEvents.user_registered(user, %{source: :web})

      # Create with additional metadata
      event = UserEvents.user_confirmed(user, %{}, correlation_id: "abc-123")

      # Invalid - raises ArgumentError
      user = %User{id: nil, email: "test@example.com", name: "Test"}
      UserEvents.user_registered(user)
      #=> ** (ArgumentError) User.id cannot be nil for user_registered event
  """

  alias PrimeYouth.Accounts.User
  alias PrimeYouth.Shared.Domain.Events.DomainEvent

  @aggregate_type :user

  @doc """
  Creates a `user_registered` event.

  This event is marked as `:critical` by default since user registration
  is a key business event that should not be lost.

  ## Parameters

  - `user` - The newly registered User struct
  - `payload` - Additional event-specific data (e.g., registration source)
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `email` - User's email address
  - `name` - User's display name
  - `intended_roles` - List of role identifiers selected during registration (["parent"], ["provider"], or both)

  Additional payload fields can be passed to include registration context.

  ## Raises

  - `ArgumentError` if `user.id` is nil
  - `ArgumentError` if `user.email` is nil or empty
  - `ArgumentError` if `user.name` is nil or empty
  - `ArgumentError` if `user.intended_roles` is not a list

  ## Examples

      iex> user = %User{id: 1, email: "test@example.com", name: "Test User"}
      iex> event = UserEvents.user_registered(user, %{source: :web})
      iex> event.event_type
      :user_registered
      iex> DomainEvent.critical?(event)
      true
  """
  def user_registered(%User{} = user, payload \\ %{}, opts \\ []) do
    validate_user_for_registration!(user)

    base_payload = %{
      email: user.email,
      name: user.name,
      intended_roles: user.intended_roles || []
    }

    opts = Keyword.put_new(opts, :criticality, :critical)

    DomainEvent.new(
      :user_registered,
      user.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  @doc """
  Creates a `user_confirmed` event.

  Emitted when a user confirms their email address, typically after
  clicking a confirmation link.

  ## Parameters

  - `user` - The confirmed User struct
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `email` - User's confirmed email address
  - `confirmed_at` - Timestamp of confirmation

  ## Raises

  - `ArgumentError` if `user.id` is nil
  - `ArgumentError` if `user.email` is nil or empty
  - `ArgumentError` if `user.confirmed_at` is nil

  ## Examples

      iex> user = %User{id: 1, email: "test@example.com", confirmed_at: ~U[2024-01-01 12:00:00Z]}
      iex> event = UserEvents.user_confirmed(user)
      iex> event.event_type
      :user_confirmed
  """
  def user_confirmed(%User{} = user, payload \\ %{}, opts \\ []) do
    validate_user_for_confirmation!(user)

    base_payload = %{
      email: user.email,
      confirmed_at: user.confirmed_at
    }

    DomainEvent.new(
      :user_confirmed,
      user.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  @doc """
  Creates a `user_email_changed` event.

  Emitted when a user changes their email address after confirmation.

  ## Parameters

  - `user` - The User struct with the new email
  - `payload` - Must include `previous_email` for audit trail
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `new_email` - User's new email address
  - `previous_email` - User's previous email (required in payload param)

  ## Raises

  - `ArgumentError` if `payload` is missing `:previous_email` key
  - `ArgumentError` if `:previous_email` is not a non-empty string
  - `ArgumentError` if `user.id` is nil
  - `ArgumentError` if `user.email` is nil or empty

  ## Examples

      iex> user = %User{id: 1, email: "new@example.com"}
      iex> event = UserEvents.user_email_changed(user, %{previous_email: "old@example.com"})
      iex> event.event_type
      :user_email_changed
      iex> event.payload.previous_email
      "old@example.com"
  """
  def user_email_changed(user, payload, opts \\ [])

  def user_email_changed(%User{} = user, %{previous_email: previous_email} = payload, opts)
      when is_binary(previous_email) and byte_size(previous_email) > 0 do
    validate_user_for_email_change!(user)

    base_payload = %{
      new_email: user.email
    }

    DomainEvent.new(
      :user_email_changed,
      user.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  def user_email_changed(%User{}, payload, _opts) do
    raise ArgumentError,
          "user_email_changed/3 requires :previous_email in payload, got keys: #{inspect(Map.keys(payload))}"
  end

  # Private validation functions

  defp validate_user_for_registration!(%User{id: nil}) do
    raise ArgumentError, "User.id cannot be nil for user_registered event"
  end

  defp validate_user_for_registration!(%User{email: email}) when is_nil(email) or email == "" do
    raise ArgumentError, "User.email cannot be nil or empty for user_registered event"
  end

  defp validate_user_for_registration!(%User{name: name}) when is_nil(name) or name == "" do
    raise ArgumentError, "User.name cannot be nil or empty for user_registered event"
  end

  defp validate_user_for_registration!(%User{intended_roles: roles})
       when not is_list(roles) and not is_nil(roles) do
    raise ArgumentError,
          "User.intended_roles must be a list for user_registered event, got: #{inspect(roles)}"
  end

  defp validate_user_for_registration!(%User{} = user), do: user

  defp validate_user_for_confirmation!(%User{id: nil}) do
    raise ArgumentError, "User.id cannot be nil for user_confirmed event"
  end

  defp validate_user_for_confirmation!(%User{email: email}) when is_nil(email) or email == "" do
    raise ArgumentError, "User.email cannot be nil or empty for user_confirmed event"
  end

  defp validate_user_for_confirmation!(%User{confirmed_at: nil}) do
    raise ArgumentError, "User.confirmed_at cannot be nil for user_confirmed event"
  end

  defp validate_user_for_confirmation!(%User{} = user), do: user

  defp validate_user_for_email_change!(%User{id: nil}) do
    raise ArgumentError, "User.id cannot be nil for user_email_changed event"
  end

  defp validate_user_for_email_change!(%User{email: email}) when is_nil(email) or email == "" do
    raise ArgumentError, "User.email cannot be nil or empty for user_email_changed event"
  end

  defp validate_user_for_email_change!(%User{} = user), do: user

  @doc """
  Creates a `user_anonymized` event.

  This event is marked as `:critical` by default since account anonymization
  is a key GDPR compliance event that must not be lost.

  ## Parameters

  - `user` - The User struct AFTER anonymization (with anonymized email)
  - `payload` - Must include `previous_email` for audit trail
  - `opts` - Metadata options (correlation_id, causation_id, user_id)

  ## Payload Fields

  Standard payload includes:
  - `anonymized_email` - User's new anonymized email (deleted_<id>@anonymized.local)
  - `previous_email` - User's previous email (required in payload param for audit)
  - `anonymized_at` - Timestamp of anonymization

  ## Raises

  - `ArgumentError` if `payload` is missing `:previous_email` key
  - `ArgumentError` if `:previous_email` is not a non-empty string
  - `ArgumentError` if `user.id` is nil

  ## Examples

      iex> user = %User{id: 1, email: "deleted_1@anonymized.local"}
      iex> event = UserEvents.user_anonymized(user, %{previous_email: "old@example.com"})
      iex> event.event_type
      :user_anonymized
      iex> DomainEvent.critical?(event)
      true
  """
  def user_anonymized(user, payload, opts \\ [])

  def user_anonymized(%User{} = user, %{previous_email: previous_email} = payload, opts)
      when is_binary(previous_email) and byte_size(previous_email) > 0 do
    validate_user_for_anonymization!(user)

    base_payload = %{
      anonymized_email: user.email,
      anonymized_at: DateTime.utc_now()
    }

    opts = Keyword.put_new(opts, :criticality, :critical)

    DomainEvent.new(
      :user_anonymized,
      user.id,
      @aggregate_type,
      Map.merge(base_payload, payload),
      opts
    )
  end

  def user_anonymized(%User{}, payload, _opts) do
    raise ArgumentError,
          "user_anonymized/3 requires :previous_email in payload, got keys: #{inspect(Map.keys(payload))}"
  end

  defp validate_user_for_anonymization!(%User{id: nil}) do
    raise ArgumentError, "User.id cannot be nil for user_anonymized event"
  end

  defp validate_user_for_anonymization!(%User{} = user), do: user
end

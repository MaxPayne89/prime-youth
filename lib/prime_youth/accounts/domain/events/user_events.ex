defmodule PrimeYouth.Accounts.Domain.Events.UserEvents do
  @moduledoc """
  Factory module for creating User domain events.

  Provides convenience functions to create standardized DomainEvent structs
  for user-related events in the Accounts context.

  ## Events

  - `:user_registered` - Emitted when a new user completes registration (critical)
  - `:user_confirmed` - Emitted when a user confirms their email
  - `:user_email_changed` - Emitted when a user changes their email address

  ## Usage

      alias PrimeYouth.Accounts.Domain.Events.UserEvents

      # Create a user_registered event (critical by default)
      event = UserEvents.user_registered(user, %{source: :web})

      # Create with additional metadata
      event = UserEvents.user_confirmed(user, %{}, correlation_id: "abc-123")
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

  Additional payload fields can be passed to include registration context.

  ## Examples

      iex> user = %User{id: 1, email: "test@example.com", name: "Test User"}
      iex> event = UserEvents.user_registered(user, %{source: :web})
      iex> event.event_type
      :user_registered
      iex> DomainEvent.critical?(event)
      true
  """
  @spec user_registered(User, map(), keyword()) :: DomainEvent.t()
  def user_registered(%User{} = user, payload \\ %{}, opts \\ []) do
    base_payload = %{
      email: user.email,
      name: user.name
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

  ## Examples

      iex> user = %User{id: 1, email: "test@example.com", confirmed_at: ~U[2024-01-01 12:00:00Z]}
      iex> event = UserEvents.user_confirmed(user)
      iex> event.event_type
      :user_confirmed
  """
  @spec user_confirmed(User, map(), keyword()) :: DomainEvent.t()
  def user_confirmed(%User{} = user, payload \\ %{}, opts \\ []) do
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

  ## Examples

      iex> user = %User{id: 1, email: "new@example.com"}
      iex> event = UserEvents.user_email_changed(user, %{previous_email: "old@example.com"})
      iex> event.event_type
      :user_email_changed
      iex> event.payload.previous_email
      "old@example.com"
  """
  @spec user_email_changed(User, map(), keyword()) :: DomainEvent.t()
  def user_email_changed(%User{} = user, payload, opts \\ []) do
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
end

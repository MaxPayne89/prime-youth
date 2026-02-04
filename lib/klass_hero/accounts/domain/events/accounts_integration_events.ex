defmodule KlassHero.Accounts.Domain.Events.AccountsIntegrationEvents do
  @moduledoc """
  Factory module for creating Accounts context integration events.

  Integration events are the public contract between bounded contexts.
  They carry stable, versioned payloads with only primitive types.

  ## Events

  - `:user_registered` - Emitted when a new user registers (critical).
    Downstream contexts (e.g. Identity) react to create profiles.

  - `:user_anonymized` - Emitted when a user is anonymized for GDPR (critical).
    Downstream contexts (e.g. Identity, Messaging) react to anonymize their data.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @source_context :accounts
  @entity_type :user

  @doc """
  Creates a `user_registered` integration event.

  Marked `:critical` by default — Identity depends on this to create profiles.

  ## Parameters

  - `user_id` - The ID of the registered user
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Payload Fields

  Standard payload includes:
  - `user_id` - The user's ID

  ## Raises

  - `ArgumentError` if `user_id` is nil or empty

  ## Examples

      iex> event = AccountsIntegrationEvents.user_registered("user-uuid")
      iex> event.event_type
      :user_registered
      iex> event.source_context
      :accounts
      iex> IntegrationEvent.critical?(event)
      true
  """
  def user_registered(user_id, payload \\ %{}, opts \\ [])

  def user_registered(user_id, payload, opts)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    base_payload = %{user_id: user_id}
    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :user_registered,
      @source_context,
      @entity_type,
      user_id,
      # Trigger: caller may pass a conflicting :user_id in payload
      # Why: base_payload contains the canonical user_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def user_registered(user_id, _payload, _opts) do
    raise ArgumentError,
          "user_registered/3 requires a non-empty user_id string, got: #{inspect(user_id)}"
  end

  @doc """
  Creates a `user_anonymized` integration event.

  Marked `:critical` by default — GDPR cascade must not be lost.

  ## Parameters

  - `user_id` - The ID of the anonymized user
  - `payload` - Additional event-specific data
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Payload Fields

  Standard payload includes:
  - `user_id` - The user's ID

  ## Raises

  - `ArgumentError` if `user_id` is nil or empty

  ## Examples

      iex> event = AccountsIntegrationEvents.user_anonymized("user-uuid")
      iex> event.event_type
      :user_anonymized
      iex> event.source_context
      :accounts
      iex> IntegrationEvent.critical?(event)
      true
  """
  def user_anonymized(user_id, payload \\ %{}, opts \\ [])

  def user_anonymized(user_id, payload, opts)
      when is_binary(user_id) and byte_size(user_id) > 0 do
    base_payload = %{user_id: user_id}
    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :user_anonymized,
      @source_context,
      @entity_type,
      user_id,
      # Trigger: caller may pass a conflicting :user_id in payload
      # Why: base_payload contains the canonical user_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def user_anonymized(user_id, _payload, _opts) do
    raise ArgumentError,
          "user_anonymized/3 requires a non-empty user_id string, got: #{inspect(user_id)}"
  end
end

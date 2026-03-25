defmodule KlassHero.Provider.Domain.Events.ProviderIntegrationEvents do
  @moduledoc """
  Factory module for creating Provider integration events.

  Integration events are the public contract between bounded contexts.

  ## Events

  - `:subscription_tier_changed` - Emitted when a provider's subscription tier changes.
    Downstream contexts (e.g., Entitlements) can react to tier changes.

  - `:staff_member_invited` - Emitted when a staff member is invited to join a provider.
    The Accounts context reacts to send the invitation email (critical).
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @typedoc "Payload for `:subscription_tier_changed` events."
  @type subscription_tier_changed_payload :: %{
          required(:provider_id) => String.t(),
          optional(atom()) => term()
        }

  @typedoc "Payload for `:staff_member_invited` events."
  @type staff_member_invited_payload :: %{
          required(:staff_member_id) => String.t(),
          optional(atom()) => term()
        }

  @source_context :provider
  @entity_type :provider_profile
  @staff_entity_type :staff_member

  def subscription_tier_changed(provider_id, payload \\ %{}, opts \\ [])

  def subscription_tier_changed(provider_id, payload, opts)
      when is_binary(provider_id) and byte_size(provider_id) > 0 do
    base_payload = %{provider_id: provider_id}

    IntegrationEvent.new(
      :subscription_tier_changed,
      @source_context,
      @entity_type,
      provider_id,
      # Trigger: caller may pass a conflicting :provider_id in payload
      # Why: base_payload contains the canonical provider_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def subscription_tier_changed(provider_id, _payload, _opts) do
    raise ArgumentError,
          "subscription_tier_changed/3 requires a non-empty provider_id string, got: #{inspect(provider_id)}"
  end

  @doc """
  Creates a `staff_member_invited` integration event.

  Marked `:critical` by default — the Accounts context must send the invitation email.

  ## Parameters

  - `staff_member_id` - The ID of the invited staff member
  - `payload` - Additional event-specific data (provider_id, email, first_name, etc.)
  - `opts` - Metadata options (correlation_id, causation_id)

  ## Payload Fields

  Standard payload includes:
  - `staff_member_id` - The staff member's ID

  ## Raises

  - `ArgumentError` if `staff_member_id` is nil or empty

  ## Examples

      iex> event = ProviderIntegrationEvents.staff_member_invited("staff-uuid")
      iex> event.event_type
      :staff_member_invited
      iex> event.source_context
      :provider
      iex> event.entity_type
      :staff_member
      iex> IntegrationEvent.critical?(event)
      true
  """
  def staff_member_invited(staff_member_id, payload \\ %{}, opts \\ [])

  def staff_member_invited(staff_member_id, payload, opts)
      when is_binary(staff_member_id) and byte_size(staff_member_id) > 0 do
    base_payload = %{staff_member_id: staff_member_id}
    opts = Keyword.put_new(opts, :criticality, :critical)

    IntegrationEvent.new(
      :staff_member_invited,
      @source_context,
      @staff_entity_type,
      staff_member_id,
      # Trigger: caller may pass a conflicting :staff_member_id in payload
      # Why: base_payload contains the canonical staff_member_id from the function argument
      # Outcome: base_payload keys always win, preventing accidental overwrite
      Map.merge(payload, base_payload),
      opts
    )
  end

  def staff_member_invited(staff_member_id, _payload, _opts) do
    raise ArgumentError,
          "staff_member_invited/3 requires a non-empty staff_member_id string, got: #{inspect(staff_member_id)}"
  end
end

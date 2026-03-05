defmodule KlassHero.Provider.Domain.Events.ProviderIntegrationEvents do
  @moduledoc """
  Factory module for creating Provider integration events.

  Integration events are the public contract between bounded contexts.

  ## Events

  - `:subscription_tier_changed` - Emitted when a provider's subscription tier changes.
    Downstream contexts (e.g., Entitlements) can react to tier changes.
  """

  alias KlassHero.Shared.Domain.Events.IntegrationEvent

  @typedoc "Payload for `:subscription_tier_changed` events."
  @type subscription_tier_changed_payload :: %{
          required(:provider_id) => String.t(),
          optional(atom()) => term()
        }

  @source_context :provider
  @entity_type :provider_profile

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
end
